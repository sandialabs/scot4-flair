#!/usr/bin/env perl

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
system("../../bin/load_core_regexes.pl");
my $data    = {
    type  => 'alertgroup',
    id          => 1234,
    data        => [
        {
            alert_id    => 44321,
            columns     => [ 'foo', 'bar', 'boom', 'baz' ],
            data        => {
                foo     => '["10.10.10.1", "20.20.20.2"]',  # note: string not array (SCOT4)
                bar     => [ 'getscot.sandia.gov', 'scotdemo.com' ], # arrary (scot3)
                boom    => 'Text that does not mean much',
                baz     => '["single element text with filename bad.exe"]',
            },
        }
    ],
};
    

$t->post_ok('/flair/v1/flair' => json => $data);
say Dumper($t->tx->res->json);
my $id  = $t->tx->res->json->{job_id};

$t->app->minion->perform_jobs;

$t->get_ok("/flair/v1/flair/$id")->status_is(200);
say Dumper($t->tx->res->json);

done_testing();

sub find_rel_dir {
    my $target = shift;
    my @path    = ();

    while (not -r join('/', @path, $target)) {
        push @path, '..';
    }
    return join('/', @path, $target);
}
