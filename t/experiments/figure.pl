#!/opt/perl/bin/perl

use lib '../../lib';
use Flair::Util::HTML qw(build_html_tree);

my $html    =<<'EOF';
<html>
    <body>
        <p>Sample</p>
        <figure class="foo" style="text: foo;">
            <table>
                <tr>
                    <td>Foo</td>
                    <td>Bar</td>
                <tr>
            </table>
        </figure>
    </body>
</html>
EOF

my $tree    = build_html_tree($html);

my $foo = $tree->as_HTML;

print $foo."\n";

