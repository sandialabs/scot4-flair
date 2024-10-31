package Flair::Parser;

use lib '../../lib';
use Data::Dumper::Concise;
use Flair::Util::Timer;
use Domain::PublicSuffix;
use Net::IPv6Addr;
use HTML::Element;
use Mojo::Base -base, -signatures;
use Try::Tiny;

# this module parses the text in a leaf node
# and returns the entities and flaired text

has 'db';
has 'log';

# used to detect false positive matches for domains
has 'public_suffix' => sub {
    return Domain::PublicSuffix->new({
        data_file   => '../../etc/public_suffix_list.dat'
    });
};

sub parse ($self, $input, $edb, $falsepos, $hint=undef) {
    $self->log->debug("PARSING $input");
    my $clean   = $self->clean_input($input);
    # load the current set of regexes.  This can be updated async
    # so we want to pay the price of database fetch to make sure we 
    # have any new flair regexes included
    my $re_aref = $self->db->regex->build_flair_regexes();
    $self->log->debug("(parse) RE array has ".scalar(@$re_aref)." elements");
    # begin the parsing of the text, which is a recursive process
    my @new     = $self->descend($edb, $input, $falsepos, $re_aref, $hint);
    return @new;
}

sub clean_input($self, $text) {
    # shim if we should need to some cleaning, like encoding utf8
    my $clean   = $text;
    return $clean;
}

sub descend ($self, $edb, $input, $falsepos, $re_aref, $hint=undef) {
    # suppress deep recursion warning
    no warnings 'recursion';

    $self->log->debug("Descending into $input");
    $self->log->debug("RE array has ".scalar(@$re_aref)." elements");

    # recursion end condition
    return if $input eq '';

    my @new         = ();
    my @regexes     = @{$re_aref};

    # if we have a hint, then only provide that re for parsing
    # e.g.  message_id columns, that way email does not match on it.
    if (defined $hint) {
        $self->log->debug("We have a hint!");
        @regexes    = grep { $_->{entity_type} eq $hint } @regexes;
    }

    # look for each regex.  first found regex wins and we move on.
    REGEX:
    foreach my $re_href (@regexes) {


        my $re  = $re_href->{regex};
        my $et  = $re_href->{entity_type};

        $self->log->debug("Using Regex ".$re_href->{name});

        # get text before, the flair, and text after match
        my ($pre, $flair, $post) = $self->find_flairable($input, 
                                                         $re, 
                                                         $et, 
                                                         $edb, 
                                                         $falsepos);

        # this regex didn't match, move to next
        next REGEX if (! defined $flair);

        # recurse into the text in the $pre (the text before the match)
        push @new, $self->descend($edb, $pre, $falsepos, $re_aref, $hint);

        # add flairable to stack
        push @new, $flair;

        # recurse into the text in the $post, pushing results onto stack
        push @new, $self->descend($edb, $post, $falsepos, $re_aref, $hint);

        # since we matched at this level, stop search
        last REGEX;
    }

    # no flairable found, so put input item on stack
    push @new, $input if scalar(@new) < 1;

    # return the stack
    return wantarray ? @new : \@new;
}

sub find_flairable ($self, $text, $re, $et, $edb, $falsepos) {
    # false positives occur, PRE store those
    my $PRE = '';
    my $fp;

    # while we have matches to the re
    MATCH:
    while ( $text =~ m/$re/g ) {

        # use perl special vars to get pre, match and post strings
        # $-[0] = index of start of match, $+[0] = index of end of match
        my $pre     = substr($text, 0, $-[0]);
        my $match   = substr($text, $-[0], $+[0] - $-[0]);
        my $post    = substr($text, $+[0]);

        $self->log->debug("we have a match for $et => $match");

        # verify match and take special actions
        my $flairable = $self->post_match_actions($match, $et,  $edb, $falsepos);

        # check for false positive
        if (! defined $flairable) {
            $fp++;
            $self->log->debug("no flairable: ");
            $self->log->trace("PRE was $PRE");
            # append $pre and $match to the PRE buffer
            $PRE .= $pre.$match;
            $self->log->trace("PRE now $PRE");
            next MATCH;
        }
        # return the flairable
        $self->log->trace("PRE.pre = ".$PRE.$pre);
        return $pre, $flairable, $post if $fp;
        return $PRE.$pre, $flairable, $post;
    }
    $self->log->debug("No match");
    # nothing found
    return undef, undef, undef;
}

sub post_match_actions ($self, $match, $et, $edb, $falsepos) {

    #  special cases
    return $self->cidr_action($match, $edb, $falsepos)          if $et eq "cidr";
    return $self->domain_action($match, $edb, $falsepos)        if $et eq "domain";
    return $self->ipaddr_action($match, $edb, $falsepos)        if $et eq "ipaddr";
    return $self->ipv6_action($match, $edb, $falsepos)          if $et eq "ipv6";
    return $self->suricata_ipv6_action($match, $edb, $falsepos) if $et eq "suricata_ipv6";
    return $self->email_action($match, $edb, $falsepos)         if $et eq "email";
    return $self->message_id_action($match, $edb, $falsepos)    if $et eq "message_id";
    return $self->cve_action($match, $edb, $falsepos)           if $et eq "cve";

    # default case
    my $span    = $self->create_span($match, $et);
    $self->add_entity($edb, $match, $et);
    return $span;
}

sub cve_action ($self, $match, $edb, $falsepos) {
    my $span    = $self->create_span_preserve_case($match, 'cve');
    $self->add_entity_preserve_case($edb, $match, 'cve');
    return $span;
}

sub cidr_action ($self, $match, $edb, $falsepos) {
    my $cidr    = $self->deobsfucate_ipdomain($match);
    $self->add_entity($edb, $cidr, 'cidr');
    return $self->create_span($match, 'cidr');
}

sub domain_action ($self, $match, $edb, $falsepos) {
    my $log     = $self->log;
    my $domain  = $self->deobsfucate_ipdomain($match);

    # if we have seen this false postive before, short circuit out of here
    if ($self->previous_false_positive_domain($edb, $domain, $falsepos)) {
        $self->log->debug("Previously seen false positive domain detected, skip");
        return undef;
    }

    return try {
        # check validity
        my $root    = $self->get_root_domain($domain, $falsepos);
        if ( ! defined $root ) {
            # invalid, so mark it and bail
            $falsepos->{domain}->{$domain}++;
            $log->warn("Domain $domain marked as false positive");
            return undef;
        }
        if ( $domain =~ m/.*\.zip$/ ) {
            # assume .zip is a file extension because that is more common
            $log->warn("Domain $domain assumed to be a file, not a domain");
            return undef;
        }

        # we have what appears to be a domain
        $self->add_entity($edb, $domain, 'domain');
        return $self->create_span($domain, 'domain'); # this returns out of the try
    }
    catch {
        # get root domain failed utterly
        $edb->{cache}->{domain_fp}->{$domain}++;
        $log->warn("Domain $domain marked false positive due to failure: $_");
        return undef;
    };
}

sub previous_false_positive_domain ($self, $edb, $domain, $falsepos) {
    # $self->log->trace("domain = $domain FP = ", {filter=>\&Dumper, value => $falsepos});
    return defined $falsepos->{domain}->{$domain};
}

sub get_root_domain ($self, $domain,$falsepos) {
    # validate that domain "could" be a real domain
    my $pds     = $self->public_suffix;
    my $root    = $pds->get_root_domain($domain, $falsepos);
    my $error   = $pds->error() // '';
    if ($error eq "Domain not valid") {
        $root   = $pds->get_root_domain('x.'.$domain, $falsepos);
        $error  = $pds->error();
        return undef if ! defined $root;
    }
    return $root;
}

sub ipaddr_action ($self, $match, $edb,$falsepos) {
    my $ipaddr  = $self->deobsfucate_ipdomain($match);
    $self->add_entity($edb, $ipaddr, 'ipaddr');
    return $self->create_span($ipaddr, 'ipaddr');
}

sub ipv6_action ($self, $match, $edb, $falsepos) {
    # see if Net::IPv6Addr things this is a valid ipv6 address
    $self->log->debug("Checking $match for IPv6-ness");
    my $ipobj   = try {
        return Net::IPv6Addr->new($match);
    }
    catch {
        $self->log->warn("invalid IPv6");
        return undef;
    };

    if (not defined $ipobj or ref($ipobj) ne "Net::IPv6Addr") {
        $self->log->warn("failed to validate potential ipv6: $match: $_");
        return undef;
    }

    # it is!
    my $standardized = $ipobj->to_string_preferred();
    $self->add_entity($edb, $standardized, 'ipv6');
    return $self->create_span($standardized, 'ipv6');
}

sub suricata_ipv6_action ($self, $match, $edb, $falsepos) {
    # suricata puts a :portnum on the end of the ipv6 addr
    my @parts   = split(/:/, $match);
    my $port    = pop @parts;
    my $ipv6    = join(':', @parts);
    my $ipobj   = Net::IPv6Addr->new($ipv6);

    if (not defined $ipobj or ref($ipobj) ne "Net::IPv6Addr") {
        $self->log->warn("failed to validate a suricata ipv6: $match: $_");
        return undef;
    }
    my $standardized = $ipobj->to_string_preferred();
    $self->add_entity($edb, $standardized, 'ipv6');
    my $span    = $self->create_span($standardized, 'ipv6');
    my $pspan   = HTML::Element->new('span');
    $pspan->push_content($span);
    $pspan->push_content(":$port");
    return $pspan;
}

sub email_action ($self, $match, $edb,$falsepos) {
    # create a nested entity span <user@<domain>>
    my ($user, $domain) = split(/\@/, $match);
    $domain = $self->deobsfucate_ipdomain($domain);

    # create entity span for domain
    my $dspan   = $self->create_span($domain, 'domain');
    $self->add_entity($edb, $domain, 'domain');

    # create span for the entire email address
    my $email   = lc($user . '@' . $domain);
    my $espan   = HTML::Element->new(
        'span',
        'class'             => 'entity email',
        'data-entity-type'  => 'email',
        'data-entity-value' => $email,
    );
    $espan->push_content($user, '@', $dspan);
    $self->add_entity($edb, $email, 'email');
    return $espan;
}

sub message_id_action ($self, $match, $edb,$falsepos) {
    # msg_id might be wrapped in < >, so make it an html entity
    my $msg_id = $match;
    if ( $match !~ m/^<.*>$/ ) {
        $msg_id =~ s/^&lt;/</;
        $msg_id =~ s/&gt;$/>/;
    }
    $self->add_entity($edb, $msg_id, 'message_id');
    return $self->create_span($msg_id, 'message_id');
}

sub create_span ($self, $match, $et) {
    # wrap match string in a span
    my $element = HTML::Element->new(
        'span',
        'class'             => "entity $et",
        'data-entity-type'  => $et,
        'data-entity-value' => lc($match),
    );
    $element->push_content($match);
    return $element;
}

sub create_span_preserve_case ($self, $match, $et) {
    # wrap match string in a span
    my $element = HTML::Element->new(
        'span',
        'class'             => "entity $et",
        'data-entity-type'  => $et,
        'data-entity-value' => $match,
    );
    $element->push_content($match);
    return $element;
}

sub add_entity ($self, $edb, $match, $et) {
    # add entity to the entity_db interim storage
    $edb->{$et}->{lc($match)}++;
}

sub add_entity_preserve_case ($self, $edb, $match, $et) {
    # add entity to the entity_db interim storage
    $edb->{$et}->{$match}++;
}

sub deobsfucate_ipdomain ($self, $text) {
    # remove things that obsfucate ipaddrs and domains
    my @parts   = split(/[\[\(\{]*\.[\]\)\}]*/, $text);
    my $clear   = join('.',@parts);
    $self->log->debug("deobsfucating $text");
    $self->log->debug("      result= $clear");
    return $clear;
}

sub parse_stringified ($self, $item, $edb, $falsepos) {
    my @new = $self->parse($item, $edb, $falsepos);
    my $result = $self->merge_elements(@new);
}

sub parse_with_hint ($self, $hint, $item, $edb, $falsepos) {
    my @new = $self->parse($item, $edb, $falsepos, $hint);
    my $result  = $self->merge_elements(@new);
}

sub merge_elements ($self, @elements) {
    my $result;
    foreach my $element (@elements) {
        $result .= (ref($element) eq "HTML::Element") 
            ? $element->as_HTML('')
            : $element;
    }
    return $result;
}

1;
