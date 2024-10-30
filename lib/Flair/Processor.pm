package Flair::Processor;

use lib '../../lib';
use Mojo::Base -base, -signatures;
use Mojo::JSON qw(encode_json);
use Data::Dumper::Concise;
use Flair::Db;
use Flair::Parser;
use Flair::Util::Models;
use Flair::Images;
use Flair::Util::Timer;     # qw(get_timer);
use Flair::Util::HTML;      # qw(build_html_tree output_tree_html generate_span create_sentinel_flair);
use Flair::Util::Sparkline; # qw(contains_sparkline normalize_sparkline data_to_sparkline_svg);
use Mojo::Pg;
use File::Basename;
use DateTime;
use HTML::Element;
use HTML::TreeBuilder;
use File::Path qw(make_path);
use MIME::Base64;
use Digest::MD5 qw(md5_hex);

# hold handle to logger
has 'log';

# get the db object from caller
has 'db'; 

# get the scotapi helper from caller
has 'scotapi';

has 'config';

# the parser class necessary to apply regexes against text
has 'parser' => sub ($self) {
    $self->log->trace("Initializing Flair Parser");

    # build parser and store in the parser slot
    my $parser   = Flair::Parser->new(
        log     => $self->log,
        db      => $self->db,
    );
    return $parser;
};

sub do_flairing ($self, $job, @args) {
    # main entry point to Flair Processing
    # called by minion task "flairjob"
    $self->log->info("Starting Flairing");

    my $parser  = $self->parser; # init the parser
    $self->db->add_metric("flairjobs_requested", 1);

    my $request_data    = $self->validate_data(@args);
    if ( ! defined $request_data ) {
        $self->log->error("Received JSON was incorrect.", {filter=>\&Dumper, value=>\@args});
        $self->db->add_metric("invalid_flairjob_request", 1);
        return;
    }

    my $timer   = get_timer();
    my $results = $self->process_request($job, $request_data);
    my $elapsed = &$timer;

    $self->store_job_metrics($job, $elapsed, $request_data, $results);

    my $send_data = $self->build_results($job, $request_data, $results);
    $self->send_results($send_data);
    $job->finish($send_data);

    my $found        = $self->count_found_entities($results);
    $self->db->add_metric("entities_found", $found);
    $self->db->add_metric("completed_flairjobs", 1);
    $self->db->add_metric("elapsed_flair_time", $elapsed);
    $self->log->info("Completed Flairing");
}

sub store_job_metrics ($self, $job, $elapsed, $request_data, $results) {
    my $size    = $self->calculate_size($request_data);
    my $ecount  = $self->count_entities($results);
    my $jobrec  = {
        job_id      => $job->id,
        duration    => $elapsed,
        imgduration => $results->{image_duration} // 0,
        sourcelen   => $size,
        images      => $results->{images_replaced}// 0,
        entities    => $ecount,
    };
    my $jobrow = $self->db->jobs->create($jobrec);
    $self->db->add_metric("parsed_data_size", $size);
    $self->db->add_metric("images_replaced", $jobrec->{images});
}

sub build_results ($self, $job, $request_data, $results) {
    my $type        = $request_data->{type};
    my $id          = $request_data->{id};
    my $send_data   = {
        target      => { type => $type, id => $id },
        entities    => $results->{entities},
    };

    if ( $type eq "entry" ) {
        $send_data->{text_flaired}  = $results->{flair};
        $send_data->{text}          = $results->{data};
        $send_data->{text_plain}    = $results->{text};
        return $send_data;
    }
    $send_data->{alerts} = $results->{alerts};
    return $send_data;
}

sub send_results ($self, $send_data) {
    $self->log->trace("send data: ",{filter => \&Dumper, value =>$send_data});
    my $response    = $self->scotapi->flair_update_scot4($send_data);
    $self->log->trace("Update Response from SCOT: ",{filter=>\&Dumper, value => $response});
}

sub process_request ($self, $job, $request_data) {
    $self->log->trace("Processing request: ",{filter=>\&Dumper, value => $request_data});
    my $type    = $request_data->{type};
    $self->log->debug("Processing $type request");
    my $timer   = get_timer();
    my $results = {};
    if ( $type eq 'entry' ) {
        $results    = $self->process_entry($job, $request_data);
    }
    elsif ( $type eq 'alertgroup' ) {
        $results    = $self->process_alertgroup($job, $request_data);
    }
    elsif ( $type eq "remoteflair") {
        $results    = $self->process_remoteflair($job, $request_data);
    }
    else {
        return { error => 'unsupported flair_type' };
    }
    $results->{elapsed_time} = &$timer;
    $self->db->add_metric($type."_processed", 1);
    return $results;
}

sub count_found_entities ($self, $results) {
    my $entities = $results->{entities};
    my $count    = 0;
    foreach my $t (keys %$entities) {
        foreach my $v (keys %{$entities->{$t}}) {
            $count++;
        }
    }
    return $count;
}



sub validate_data ($self, @args) {
    # 
    ## make sure the input to the process is good
    # expecting 
    #
    # alertgroup
    #    {
    #        "id": 123,
    #        "type": "alertgroup",
    #        "data": {
    #            "alerts": [
    #                {
    #                    "id": 456,
    #                    "row": {
    #                        "col1": "data1", ...
    #                        "colx": "datax"
    #                    }
    #                },
    #                ...
    #            ]
    #        }
    #    }

    # event 
    #     {
    #         "id": 123,
    #         "type": "entry",
    #         "data": "string data to flair",
    #     }


    $self->log->trace("validating:", {filter=>\&Dumper, value=>\@args});

    my $href    = $args[0];
    my $type    = $href->{type};
    my $id      = $href->{id};
    my $data    = $href->{data};

    if     (   $type ne "alertgroup" 
               and $type ne "entry" 
               and $type ne "remoteflair") {
        $self->log->warn("Invalid type in received json.  type = $type");
        return undef;
    }
    
    if ($id < 1) {
        $self->log->warn("target id is invalid.  id = $id");
        return undef;
    }


    # data should always be an object for alertgroups
    if ($type eq "alertgroup" and ref($data) ne "HASH") {
        $self->log->warn("type is alertgroup, but data is not a hash!");
        return undef;
    }

    # data.alerts should be an array of hashes
    if ($type eq "alertgroup" and ref($data->{alerts})      ne "ARRAY") {
        $self->log->warn("type is alertgroup, but data.alerts is not an array");
        return undef;
    }
    if ($type eq "alertgroup" and ref($data->{alerts}->[0]) ne "HASH") {
        $self->log->warn("type is alertgroup, but data.alerts.0 is not a hash");
        return undef;
    }

    # entries should be not null
    if ($type eq "entry" and $data eq ''){
        $self->log->warn("type is entry, but data is null string");
        return undef;
    }

    # entries should not be scalars
    if ($type eq "entry" and ref($data) ne '') {
        $self->log->warn("type is entry, but data is a reference, not a string");
        return undef;
    }

   return {
        type            => $type,
        id              => $id,
        data            => $data,
    };
}

sub calculate_size ($self, $href) {
    if ($href->{type} eq "entry" || $href->{type} eq "remoteflair") {
        return length($href->{data});
    }
    my $size = 0;
    foreach my $alert (@{$href->{data}->{alerts}}) {
        foreach my $cell (keys %{$alert->{row}}) {
            # cell is a stringified json array, so just count chars
            # as a rough approximation
            $size += length($cell);
        }
    }
    return $size;
}

sub count_entities ($self, $results) {
    my $edb     = $results->{entities};
    my $count   = 0;
    foreach my $type (keys %$edb) {
        foreach my $value (keys %{$edb->{$type}}) {
            $count += $edb->{$type}->{$value};
        }
    }
    return $count;
}

sub process_alertgroup ($self, $job, $request_data) {

    # given an alertgroup, split the data into alerts
    # and process each alert

    my @results = ();
    my $edb     = {};
    my $falsepos= {};

    foreach my $alert (@{$request_data->{data}->{alerts}}) {
        $alert->{alertgroup} = $request_data->{id};
        my $alert_result = $self->flair_alert($alert, $falsepos);
        push @results, $alert_result;
        $self->merge_edb($edb, $alert_result->{entities});
    }

    $self->log->debug("Flaired Alerts Result ",{filter=>\&Dumper, value => \@results});

    return {
        type        => 'alertgroup',
        id          => $request_data->{id},
        entities    => $edb,
        alerts      => \@results,
        job_id      => $job->id,
    };
}

sub process_entry ($self, $job, $request_data) {

    my $edb         = {};
    my $falsepos    = {};

    my $img_timer   = get_timer();

    $self->log->debug("ORIG DATA is ",{filter=>\&Dumper, value=>$request_data->{data}});

    # build "tree" structure of html
    my $tree    = build_html_tree($request_data->{data});

    # descend through tree looking for images and cacheing them
    my $imgmunger    = Flair::Images->new(log => $self->log, 
                                          scotapi => $self->scotapi,
                                          config => $self->config);
    my $replacements = $imgmunger->process($tree);

    # if images were replaced, store the current state of the tree
    # as the new "original" data.  Otherwise, use the submitted
    # text as the original.  
    my $orig_data   = ($replacements)   ? $tree->as_HTML 
                                        : $request_data->{data};

    # walk the tree looking for flairables
    $self->walk_tree($tree, $edb, $falsepos);
    
    # write the modified tree to html
    my ($flaired_data, $plain_data) = output_tree_html($tree);

    $self->log->debug("FLAIRED DATA is $flaired_data");
    $self->log->debug("PLAIN   DATA is $plain_data");

    # trees can cause memory leaks if not deleted explicitly
    $tree->delete;

    return {
        type    => 'entry',
        id      => $request_data->{id},
        data    => $orig_data,
        flair   => $flaired_data,
        text    => $plain_data,
        entities => $edb,
        images_replaced => $replacements,
        image_duration  => &$img_timer,
    };
}

sub process_remoteflair ($self, $job, $request_data) {
    # assume that browser extension is procxied through scot api
    my $edb         = {};
    my $falsepos    = {};
    my $orig_data   = $request_data->{data};

    # build "tree" structure of html
    my $tree    = build_html_tree($orig_data);

    # walk the tree looking for flairables
    $self->walk_tree($tree, $edb, $falsepos);
    
    # write the modified tree to html
    my ($flaired_data, $plain_data) = output_tree_html($tree);

    # trees can cause memory leaks if not deleted explicitly
    $tree->delete;

    return {
        type    => 'remoteflair', 
        id      => $request_data->{id},
        data    => $orig_data,
        flair   => $flaired_data,
        text    => $plain_data,
        entities => $edb,
    };
}

sub walk_tree ($self, $element, $edb, $falsepos) {
    # recursively descend into html tree, look for flair when leaf node is found
    return if $element->is_empty;

    # concatenate adjacent text nodes 
    $element->normalize_content;

    # get the list of content nodes
    my @content = $element->content_list;
    my @new     = ();                       # hold updated elements

    # examine each element in @content list
    for (my $index = 0; $index < scalar(@content); $index++) {

        my $child   = $content[$index];

        if ($self->is_leaf_node($child)) {
            # we are ready to parse for flair
            push @new, $self->parser->parse($child, $edb, $falsepos);
            next;
        }

        if ($self->is_predefined_entity($child, $edb)) {
            # add unmodified element, entity was added as side effect in the check
            push @new, $child;
            next;
        }

        if ($self->is_no_flair_span($child)) {
            $self->log->debug("No Flair Span found, skipping over");
            push @new, $child;
            next;
        }

        if ($self->is_flair_override_span($child)) {
            $self->log->debug("Found a flair override span");
            push @new, $self->extract_flair_override($child, $edb);
            next;
        }

        # splunk used to do a weird thing with ipaddresses
        # were the html looked like: 10<em>.</em>10<em>.</em>10<em>.</em>1
        # (but I dont think it does it anymore).  If we encounder this again
        # we would write something here to detect and re-write it.  See
        # SCOT3 flair for example
        
        # recurse into any "grandchilderen"
        $self->walk_tree($child, $edb, $falsepos);

        # push any changes made below onto the new stack
        push @new, $child;
    }
    # replace tree branches with changes held in @new
    $element->splice_content(0, scalar(@content), @new);
}

sub is_no_flair_span ($self, $node) {
    # idea is to detect <span class="noflair">stuff</span>
    # or <noflair></noflair>
    # and skip over it
    
    if ( $self->node_is_span($node) ) {
        return ($self->class_is($node, "noflair"));
    }
    return $self->node_is_noflair($node);

}

sub class_is ($self, $node, $match) {
    my $class = $node->attr('class');
    return ($class eq $match);
}

sub is_flair_override_span ($self, $node) {
    # ideas is to detect <span class="flairoverride" data-entity-type="type">sting</span>
    # and create an entity of type "type" without actually doing the parsing
    if ($self->node_is_span($node)) {
        my $class   = $node->attr('class');
        return ($class eq "flairoverride");
    }
    return undef;

}

sub extract_flair_override($self, $node, $edb) {
    # get node text
    my @content     = $node->content_list();
    if (scalar(@content) > 1) {
        $self->log->error("Nested content in flair override not supported!");
        return $node;
    }
    my $text    = pop @content;
    # get type
    my $type = $node->attr('data-entity-type');
    # add it to edb
    $edb->{$type}->{$text}++;
    # rewrite <span> to be a standard flair span
    my $span    = HTML::Element->new(
        'span', 
        'class'             => "entity $type",
        'data-entity-type'  => $type,
        'data-entity-value' => lc($text),
    );
    $span->push_content($text);
    # return the element
    return $span;
}

sub is_leaf_node ($self, $child) {
    return ref($child) eq '';
}

sub node_is_span ($self, $node) {
    my $tag = $node->tag;
    # $self->log->trace("node tag is $tag");
    return ($tag eq "span");
}

sub node_is_noflair ($self, $node) {
    my $tag = $node->tag;
    return ($tag eq "noflair");
}

sub is_predefined_entity ($self, $node, $edb) {
    # entities could come in pre-defined from other services, or a copy
    # of a flaired entry
    # currently they must come in as 
    # <span class="entity foo" data-entity-type="foo" data-entity-value="bar">bar</span>

    my $tag = $node->tag;
    return undef if $tag ne "span";

    my $class = $node->attr('class');
    return undef if $class !~ /entity/i;

    my $type  = $node->attr('data-entity-type');
    return undef if not defined $type;

    my $value = $node->attr('data-entity-value');
    return undef if not defined $value;

    # add to edb, but no transformation of child is necessary
    # since it is already in "flair" form
    $edb->{$type}->{$value}++;
    return 1;
}

sub flair_alert ($self, $alert, $falsepos) {
    $self->log->trace("Alert data = ", {filter=>\&Dumper, value=>$alert});
    # process_alertgrop calls this
    my $data        = $alert->{row};
    my $flair       = {}; # flaired text of alert by column
    my $text        = {}; # plain text of alert by column
    my $alert_edb   = {}; # entity found cache


    # examine each column in the alert row
    COLUMN:
    foreach my $column (keys %$data) {

        $self->log->trace("Column = $column");

        # skip over columns we do not want to process
        next COLUMN if $self->is_skippable_column($column);

        # cell is an array ref of 1 or more text items
        my $cell = $data->{$column};
        $self->log->trace("looking at column $column cell:", {filter=>\&Dumper, value=>$cell});

        # detect sparkline data and draw a sparkline svg if present
        # some alertgroups could have multiple sparklines
        if (contains_multi_row_sparklines($cell)) {
            $self->log->debug("Multi-row sparklines detected in columne $column: $cell");
            my $table     = $self->build_multi_sparkline_table($cell);
            $self->log->debug("---- TABLE built ----");
            $self->log->debug({filter => \&Dumper, value => $table});
            my $tresult   = $self->flair_table($alert, $column, $table, $falsepos);
            $flair->{$column} = $tresult->{flair};
            $text->{$column}  = $tresult->{text};
            $self->merge_edb($alert_edb, $tresult->{entities});
            next COLUMN;
        }
        elsif (contains_sparkline($cell)) {
            $self->log->debug("Sparkline detected in cell with column $column: $cell");
            my $sparkline = data_to_sparkline_svg($cell);
            $self->log->debug("converted to $sparkline");
            $flair->{$column} = $sparkline;
            # single sparkline data cells need no additional flairing
            next COLUMN;
        }
        else {
            $self->log->trace("NO SPARKLINES");
        }

        # descend into the cell and flair
        my $cell_flair_result = $self->flair_cell($alert, $column, $cell, $falsepos);

        # build up data for this alert
        $flair->{$column}   = $cell_flair_result->{flair};
        $text->{$column}    = $cell_flair_result->{text};

        # Add found entities in cell to the alert edb
        $self->merge_edb($alert_edb, $cell_flair_result->{entities});
    }

    # add this alert's results to alertgroup results
    return {
        id          => $alert->{id},
        flair_data  => $flair,
        text_data   => $text,
        entities    => $alert_edb,
    };
}

sub build_multi_sparkline_table ($self, $data) {
    my $table     = HTML::Element->new('table');
    my $style     = "border: 1px solid black; border-collapse: collapse;";
    $table->push_content(
        ['tr'],
          ['th', 'IOC'],
          ['th', 'Indices'],
          ['th', 'Hits'],
          ['th', 'Sparkline'],
    );
    foreach my $row (split(/\n/,$data)) {
        next if ($row =~ /MULTILINE/);
        my ($ioc, $hits, $sparkdata, $indices) = split(',',$row);
        my $sparkline = data_to_sparkline_svg($sparkdata);
        my $tr  = HTML::Element->new('tr');
        $tr->push_content(['td', { style => $style }, $ioc]);
        $tr->push_content(['td', { style => $style }, join('<br>', split(/:/,$indices))]);
        $tr->push_content(['td', { style => $style }, $hits]);
        $tr->push_content(['td', { style => $style }, $sparkline]);
        $table->push_content($tr);
    }
    return $table->as_HTML(''); 
}

sub is_skippable_column ($self, $column) {
    # add skippable column check here
    return 1 if $column eq 'columns';
    return 1 if $column eq '_raw';
    return 1 if $column eq 'search';
    return undef;
}

sub flair_cell ($self, $alert, $column, $cell, $falsepos) {
    my $cell_type   = $self->get_column_type($column);
    my $alert_id    = $alert->{id};
    my $ag_id       = $alert->{alertgroup};

    # hold the flairables
    my $edb     = {};
    my @flair   = ();
    my @text    = ();

    # expect input in one of two ways:
    # SCOT3 => array ref
    # SCOT4 => string of format: '["item1",..."itemx"]'

    # if we get a SCOT4 input, change into an array
    if ( ref($cell) ne "ARRAY" ) {
        $cell   = $self->arrayify_string($cell);
    }

    foreach my $item (@$cell) {
        next if $self->item_is_empty($item);
        # process normal columns
        if ( $cell_type eq "normal" ) {
            my $item_result = $self->flair_normal_item($self->clean_html($item), $falsepos);
            $self->merge_edb($edb, $item_result->{edb});
            push @flair, $item_result->{flair};
            push @text,  $item_result->{text};
            next;
        }

        # OK, we have a "special" cell type
        my $item_result = $self->flair_special_item($alert, $cell_type, $column, $item, $falsepos);
        # add the results to the cell
        $self->merge_edb($edb, $item_result->{edb});
        # return the cell results to flair_alert
        push @flair, $item_result->{flair};
        push @text,  $item_result->{text};
    }

    # testing json array
    return {
        flair   => \@flair,
        text    => \@text,
        entities=> $edb,
    };
    # stringify array return
    return {
        flair   => $self->stringify_array(\@flair),
        text    => $self->stringify_array(\@text),
        entities=> $edb,
    };
}

sub flair_table ($self, $alert, $column, $table, $falsepos) {
    # CTI submitted an array of sparkline data, that has been converted
    # to a html table earlier in this process.  we now flair it.
    my $alert_id    = $alert->{id};
    my $ag_id       = $alert->{alertgroup};

    my $edb     = {};
    my @flair   = ();
    my @text    = ();

    # table is an HTML::Element
    my $result  = $self->flair_table_item($self->clean_html($table), $falsepos);
    push @flair, $result->{flair};
    push @text, $result->{text};

    my $fref = {
        flair   => \@flair,
        text    => \@text,
        entities    => $result->{edb},
    };
    # $self->log->trace("flair_table result = ",{filter=>\&Dumper, value => $fref});
    return $fref;
}

sub contains_table_html ($self, $item) {
    # grep for table tag, return true if found
    return grep { /<table.*>/ } ($item); 
}

sub flair_normal_item ($self, $input, $falsepos) {
    # send "normal" text to the parser to iterate through regular
    # expression set.  
    my $edb   = {};
    # special case, there may be an anchor tag present.  if so, assume
    # that it is there because they want to have a hyperlink therefore
    # do not flair the hyperlink (which will "break" it)
    if ($self->is_anchor($input)) {
        $self->log->debug("Anchor detected: not parsing for flair");
        return {
            flair   => $self->process_anchor($input),
            text    => $input,
            edb     => $edb,
        };
    }
    my $flair = $self->parser->parse_stringified($input, $edb, $falsepos);
    return {
        flair   => $flair,
        text    => $input,
        edb     => $edb,
    };
}

sub flair_table_item ($self, $input, $falsepos) {
    # we have encountered a sub-table that has an html table and will need to 
    # be parsed more like an entry
    my $edb     = {};
    my $tree    = build_html_tree($input);

    $self->log->debug("flair_table_time with input = ".$tree->as_HTML(''));

    $self->log->debug("Walking tree of multi-row sparkline table");
    # descend into html tree to find entities
    $self->walk_tree($tree, $edb, $falsepos);

    #$self->log->debug("Walked the tree");

    # get the flaired data, in this case not really using plain_data
    my ($flaired_cell_table, $plain_data) = output_tree_html($tree);
    #$self->log->debug("EDB = ", {filter=>\&Dumper, value => $edb});
    #$self->log->debug("FALIR = ", {filter=>\&Dumper, value => $flaired_cell_table});

    return { 
        flair   => $flaired_cell_table,
        text    => $input,
        edb     => $edb,
    };
}


sub flair_special_item ($self, $alert, $cell_type, $column, $item, $falsepos) {
    my $edb     = {};
    my $text    = $item; # assume we have text
    my $flair;

    if ( $cell_type eq 'sentinel' ) {
        return $self->flair_sentinel_type($item);
    }

    if ( $cell_type eq "message_id" ) {
        return $self->flair_message_id_type($item, $falsepos);
    }

    # add future special types here like this:
    # if ( $cell_type eq 'special_type' ) {
    #   $flair = $self->flair_whatever($item, $edb)
    #   return { flair => $flair, text => $text, edb => $edb }
    # }
    # or 
    # return $self->flair_whatever_type($item) if ($cell_type eq "whatever_type");

    # default case:  assume that the "type" of the cell === entity type
    # and create a <span> to mark the item
    $edb->{$cell_type}->{lc($item)}++;
    $flair = generate_span($cell_type, $item);

    return { flair => $flair, text => $text, edb => $edb };
}

sub flair_message_id_type ($self, $item, $falsepos) {
    my $edb = {};
    my $flair   = $self->parser->parse_with_hint('message_id', $item, $edb, $falsepos);
    return { flair => $flair, text => $item, edb => $edb };
}

sub is_anchor ($self, $data) {
    if ($data =~ /<a href=.*\/a>/) {
        return 1;
    }
    return undef;
}
sub process_anchor ($self, $data) {
    # for now, just return the anchor string
    return $data;
    # later, we can do some validation, or other post processing
    # on the anchor in this function
}


sub flair_sentinel_type ($self, $item) {
    my $edb     = { sentinel => { $item => 1}};
    my $flair   = create_sentinel_flair($item);
    return { flair => $flair, text => $item, edb => $edb };
}


sub get_column_type ($self, $column) {
    return 'message_id'  if $column =~ /message[_-]id/i;
    return 'uuid1'       if $column =~ /^(lb){0,1}scanid$/i;
    return 'filename'    if $column =~ /^attachment[_-]name/i;
    return 'filename'    if $column =~ /^attachments$/i;
    return 'sentinel'    if $column =~ /^sentinel_incident_url$/i;
    return 'normal';
}

sub merge_edb ($self, $existing, $new) {
    # add newly found entities to an existing edb
    # updated $existing as a side effect
    foreach my $type (keys %{$new}) {
        foreach my $entity_string (keys %{$new->{$type}}) {
            $existing->{$type}->{$entity_string} += $new->{$type}->{$entity_string};
        }
    }
}

sub arrayify_string ($self, $string) {
    # SCOT provides stringified arrays for alert cells
    # of the format '["foo", "bar", "boom"]'
    # this will turn that into an array with elements ("foo", "bar", "boom" )

    my @a   = split(/",[ ]*"/, $string);   # ["foo , bar, boom"]
    $a[0]   =~ s/^\[\"//g;                 # foo, bar, boom"]
    $a[-1]  =~ s/\"\]$//g;                 # foo, bar, boom
    return wantarray ? @a : \@a;
}

sub stringify_array ($self, $arrayref) {
    # create a string: ["item1", "item2", "itemX"] from an array ['item1', 'item2', 'item3']
    my $string = '[' 
                 .  join(', ', map { $self->wrapq($_); } @$arrayref) 
                 . ']';
    return $string;
}

sub wrapq ($self, $item) {
    # wrap item in ""
    my $q   = "\"";
    return join('', $q, $item, $q);
}

sub get_html_tree ($self, $html) {
    return build_html_tree($html);
}

sub ensure_array ($self, $cell) {
    # if cell is an array reference, return an array
    # if not create an array and return it with cell as first element
    return @$cell if (ref($cell) eq "ARRAY");
    return ( $cell );
}

sub item_is_empty ($self, $item) {
    return 1 if ($item eq '');
    return 1 if not defined $item;
    return undef;
}

sub clean_html ($self, $item) {
#   TODO!
    return $item;
}

1;
