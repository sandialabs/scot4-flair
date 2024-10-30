#!/usr/bin/env perl

use TAP::Harness;
my %args    = ( verbosity => 1 );
my $harness = TAP::Harness->new(\%args);
$harness->runtests(
    './config.t',
    './sparkline.t',
    './html.t',
    './timer.t',
);
