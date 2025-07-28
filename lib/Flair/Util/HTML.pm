package Flair::Util::HTML;

# export useful functions to do with html parsing and creation

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(build_html_tree 
             output_tree_html 
             generate_span
             create_sentinel_flair
             create_message_id_flair
          );

use strict;
use warnings;
use feature qw(say signatures);
no warnings qw(experimental::signatures);

use HTML::TreeBuilder;
use HTML::Element;
use HTML::Entities;
use Data::Dumper::Concise;

sub build_html_tree ($text) {
    if ( $text !~ /^<.*>/ ) { # does not start with an html tag looking thing
        $text = '<div>'.$text.'</div>';     # voila, html
    }

    # TreeBuilder parses the "HTML" passed in and creates a tree structure
    # for easy traversal 

    my $tree    = HTML::TreeBuilder->new;
       $tree    ->implicit_tags(1);
       $tree    ->p_strict(1);
       $tree    ->no_space_compacting(1);
       $tree    ->no_expand_entities(1); # prevent decodeing of html entities
       $tree    ->ignore_unknown(0);     # allow stuff like <figure/>
       $tree    ->parse_content($text);
       $tree    ->elementify;
    ##
    ## when dumping the tree as plain text, any tables will have cells 
    ## smashed together.  This function will add some spaces to tree 
    ## and will fix this
    insert_table_element_spaces($tree);
    return $tree;
}

sub insert_table_element_spaces ($tree) {
    foreach my $td ($tree->look_down('_tag', 'td')) {
        $td->preinsert(" ");
    }
    foreach my $th ($tree->look_down('_tag', 'th')) {
        $th->preinsert(" ");
    }
}

sub output_tree_html ($tree) {
    # a $tree is full document, we really only want body
    my $body    = $tree->look_down('_tag', 'body');
    return undef if not defined $body; # no body, nothing to do

    my @content = $body->detach_content;
    return undef if scalar(@content) < 1; # no content, nothing to do

    if (scalar(@content) == 1 and $content[0]->tag eq 'div') {
        return $content[0]->as_HTML(''), $content[0]->as_text();
    }

    # wrap content into new div 
    my $div = HTML::Element->new('div');

    # add the detatched content to new div
    $div->push_content(@content);   

    # return the html.  
    # the '' instructs function to not change anyting to html entities 
    # e.g.  < to &lt;
    return $div->as_HTML(''), $div->as_text();
}

sub generate_span ($type, $item) {
    # encode entities so things like internet_message_id's that have <> 
    # do not break the HTML display.  If encode_entities is too aggressive
    # we can specify limits to what encode_entities changes.  (see perldoc HTML::Entities)
    # e.g. encode_entities($foo, '<>&') would only replace < > and &.
    my $encoded = encode_entities($item);
    return qq|<span class="entity"|.
           qq| data-entity-type="$type"|.
           qq| data-entity-value="$item">$encoded</span>|;
}

sub create_sentinel_flair ($url) {
    my $image = HTML::Element->new(
        'img',
        'alt', 'View in Azure Sentinel',
        'src', '/images/azure-sentinel.png',
    );
    my $anchor = HTML::Element->new(
        'a',
        'href', $url,
        'target', '_blank'
    );
    $anchor->push_content($image);
    return $anchor->as_HTML(''); # the '' prevents encoding of html entities
}

sub create_message_id_flair ($item) {
    return generate_span('message_id', $item);
}


1;
__END__
=head1 Name

Flair::Util::Tree

=head1 Description

Package of convenience functions for workign with/from HTML

=head1 Synopsis

my $html = "<html><body><h1>Foo</h1><p>10.10.10.1</p></body></html>"
my $tree = build_html_tree($html);
my $newhtml = output_tree($tree);

=head1 Author

Todd Bruner (tbruner@sandia.gov)

=cut

