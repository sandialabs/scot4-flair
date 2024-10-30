use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use lib './lib','../lib';
use Log::Log4perl;
say `pwd`;
my $file = find_rel_dir('etc/testlog.conf');
say $file;
Log::Log4perl::init($file);

my $t = Test::Mojo->new('Flair');
$t->get_ok('/')->status_is(200)->content_like(qr/Mojolicious/i);
$t->get_ok('/flair/v1/regex')->status_is(200);

done_testing();

sub find_rel_dir {
    my $target = shift;
    my @path    = ();

    while (not -r join('/', @path, $target)) {
        push @path, '..';
    }
    return join('/', @path, $target);
}