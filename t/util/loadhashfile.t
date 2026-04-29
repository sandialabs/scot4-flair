#!/usr/bin/env perl

use Test::More;
use Test::Deep;
use lib '../../lib';

use Flair::Util::LoadHashFile;
use Data::Dumper::Concise;

my $lhf     = Flair::Util::LoadHashFile->new();

done_testing();

