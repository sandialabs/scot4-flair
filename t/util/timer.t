#!/usr/bin/env perl

use Test::More;
use Test::Deep;
use lib '../../lib';

use Flair::Util::Timer;
use Data::Dumper::Concise;
use feature qw(say);

my $timer1 = get_timer();
sleep 1;
my $e1 = &$timer1;

say $e1;
ok ($e1 < 2, "Timer probably correct");

is ( get_english_duration(3600),"1 hour", "duration correct");

my $dt  = DateTime->now();
is ( get_ymdhms_time(), join(' ',$dt->ymd, $dt->hms), "get_ymdhms_timer correct");


done_testing();

