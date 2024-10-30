#!/usr/bin/env perl

use TAP::Harness;
my %args    = ( verbosity => 1 );
my $harness = TAP::Harness->new(\%args);
$harness->runtests(
    'imgproc.t',
    'job.t',
    'parser.t',
    'processor.t',
    'task_flair.t'
);
