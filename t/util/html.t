#!/opt/perl/bin/perl

use Test::More;

use lib '../../lib';
use Flair::Util::HTML;

my $html = << 'EOF';
<html>
    <head>
        <title>Foobar</title>
    </head>
    <body>
        <ul>
            <li>Foo</li>
            <li>Bar</li>
        </ul>
    </body>
</html>
EOF

my $tree    = build_html_tree($html);

is(ref($tree), "HTML::Element", "Got expected object");

my ($div, $plain) = output_tree_html($tree);
is ($div, '<div><ul><li>Foo<li>Bar</ul></div>', "Tree round trip worked");
is ($plain, 'FooBar', 'So did plain text');

my $span    = generate_span("foobar", "boombaz");
is($span, '<span class="entity foobar" data-entity-type="foobar" data-entity-value="boombaz">boombaz</span>', "Generated span correctly");

my $sentinel = create_sentinel_flair("http://foo.com/xyz");
is ($sentinel, '<a href="http://foo.com/xyz" target="_blank"><img alt="View in Azure Sentinel" src="/images/azure-sentinel.pmg" /></a>', "created sentinel anchor correctly");


my $xss = q{<p>&lt;script&gt;alert(1);&lt;/script&gt;</p>};
my $xtree    = build_html_tree($xss);
my ($xdiv, $xplain) = output_tree_html($xtree);

print <<"EOF";
XSS   = $xss
DIV   = $xdiv
PLAIN = $xplain
EOF

done_testing();
exit 0;
