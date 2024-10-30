#!/opt/perl/bin/perl

use Mojo::Base -strict;
use Test::Most;
use Data::Dumper::Concise;

use lib '../lib';
use Flair::Falsepos;

my $fp  = Flair::Falsepos->new;
is (ref($fp), "Flair::Falsepos", "instantiated object") 
or die "failed to create false pos object";

$fp->add("foo.com");
my $href = $fp->as_hash;
cmp_deeply($href, { "foo.com" => 1 }, "Added foo.comf")
or die "failed to add foo.com";

ok($fp->is_false_positive("foo.com"), "found false pos")
or die "failed to find false positive";

ok(! $fp->is_false_positive("bar.com"), "correctly did not identify falsepos")
or die "failed by identifying an ok domain as false positive";

done_testing();
exit 0;
