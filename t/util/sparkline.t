#!/opt/perl/bin/perl

use Test::Most;

use lib '../../lib';
use Flair::Util::Sparkline;
use Data::Dumper::Concise;
use feature qw(say);

my $data    = '[ "##__SPARKLINE__##", "1", "2", "", "4", "0", "5" ]';

ok (contains_sparkline($data), "correctly identified a sparkline string");
ok (!contains_sparkline('1,3,4,4'), "correctly did not identify a numeric string");

my @sdata = normalize_sparkline_string($data);
is (scalar(@sdata), 5, "correct number of elements");

my $svg = data_to_sparkline_svg($data);
is ($svg, '<svg height="12" viewBox="0 -11 9 12" width="9" xmlns="http://www.w3.org/2000/svg"><polyline fill="none" points="0,-2 2,-4 4,-8 6,0 8,-10" stroke="blue" stroke-linecap="round" stroke-width="1" /></svg>', "Correct SVG generated");

my @d = ('##__SPARKLINE__##', '5', '4', '', '3', '2','1');
ok(contains_sparkline(\@d), "correctly identified a sparkline array");
ok(!contains_sparkline([1,2,3]), "correctly did not identify numerica array as sparkline");

my @s2data = normalize_sparkline_array(\@d);
is (scalar(@s2data), 5, "correct number of elements");
my $svg2 = data_to_sparkline_svg(\@d);
is($svg2, "<svg height=\"12\" viewBox=\"0 -11 7 12\" width=\"7\" xmlns=\"http://www.w3.org/2000/svg\"><polyline fill=\"none\" points=\"0,-10 2,-6.67 4,-3.33 6,0\" stroke=\"blue\" stroke-linecap=\"round\" stroke-width=\"1\" /></svg>", "Correct SVG");


done_testing();
exit 0;
