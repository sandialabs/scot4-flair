#!/opt/perl/bin/perl
#
use lib '../lib';
use Flair::Util::HTML;
use Test::More;


my $html    = <<'EOF';
  <table> <tr><th>BOOM</th><th>BAZ</th></tr><tr> <td>foo</td> <td>bar</td> </tr> </table>
EOF

my $tree  = build_html_tree($html);
is ($tree->as_text()," BOOM BAZ foo bar", "got correct text");



