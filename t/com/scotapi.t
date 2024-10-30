#!/usr/bin/env perl
use Mojo::Base -strict;
use strict;
use warnings;

use Test::More;
use Data::Dumper::Concise;
use Log::Log4perl;
use lib '../../lib';
use Flair::ScotApi;

my $file = find_rel_dir('etc/testlog.conf');
say $file;
Log::Log4perl::init($file);
my $log  = Log::Log4perl->get_logger();
my $scotbaseuri = "https://as3001snllx.sandia.gov/scot/api/v2";
my $config  = {
    insecure    => 1,
    api_key     => '532EC1B6-8968-11EA-8F10-5AA486A3F2C3',
    uri_root    => $scotbaseuri,
};


my $api = Flair::ScotApi->new(
    log     => $log,
    config  => $config,
);

is(ref($api), "Flair::ScotApi", "Got ScotApi object");
is(ref($api->ua), "Mojo::UserAgent", "It has a Mojo::UA in it");

my $alertgroup = $api->fetch('alertgroup', 1712852);

is($alertgroup->{id}, 1712852, "Got the correct alertgroup");
is($alertgroup->{alerts}->[0]->{id}, 41837469, "The alert is correct");

my $entry = $api->fetch('entry', 10);
is($entry->{id}, 10, "Got the Entry");
is($entry->{target}->{id}, 2, "Target Id correct");
is($entry->{target}->{type}, "event", "Target Id correct");

my $body    = $entry->{body} =~ s/CVA/CVA2/rg;
my $flair   = $entry->{body_flair} =~ s/CVA/CVA2/rg;
my $text    = $entry->{body_plain} =~ s/CVA/CVA2/rg;


my $patch_data = {
    type    => "entry",
    id      => 10,
    data    => {
        body    => $body,
        body_flair  => $flair,
        body_plain  => $text,
    },
};
my $entryupdate = $api->flair_update($patch_data);

$entry = $api->fetch('entry', 10);
ok($entry->{body}       =~ /CVA2/, "Body updated");
ok($entry->{body_flair} =~ /CVA2/, "Flair updated");
ok($entry->{body_plain} =~ /CVA2/, "Plain updated");

say Dumper($entry);
done_testing();
exit 0;

sub find_rel_dir {
    my $target = shift;
    my @path    = ();

    while (not -r join('/', @path, $target)) {
        push @path, '..';
    }
    return join('/', @path, $target);
}
