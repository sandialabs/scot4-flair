use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use lib '../../lib';
use Log::Log4perl;
use Flair::Task::Flair;
say `pwd`;
my $file = find_rel_dir('etc/testlog.conf');
say $file;
Log::Log4perl::init($file);
use Data::Dumper::Concise;

my $t = Test::Mojo->new('Flair');
my $pi = $t->app->plugins;

say Dumper $pi;

done_testing();

sub find_rel_dir {
    my $target = shift;
    my @path    = ();

    while (not -r join('/', @path, $target)) {
        push @path, '..';
    }
    return join('/', @path, $target);
}
