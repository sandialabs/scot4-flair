#!/usr/bin/env perl
unlink "./flairtest.db";
use TAP::Harness;
my %args    = ( verbosity => 1 );
my $harness = TAP::Harness->new(\%args);
$harness->runtests(
    './db.t',
    './admins.t',
    './apikeys.t',
    './metric.t',
    './regex.t',
);
