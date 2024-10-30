#!/usr/bin/env perl

use TAP::Harness;
my %args    = ( verbosity => 1 );
my $harness = TAP::Harness->new(\%args);
$harness->runtests(
    './regex.t',
    './apikeys.t',
    './metrics.t',
    #  './files.t',
);
