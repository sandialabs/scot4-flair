#!/opt/perl/bin/perl

use Test::Most;

use lib '../lib';
use Flair::Edb;

my $e   = Flair::Edb->new();
my $x   = Flair::Edb->new();

$e->add('foo', 'bar');
$e->add('foo', 'bar');
$e->dump;

$x->add('boom', 'baz');
$x->dump;

$e->merge($x);
$e->dump;

