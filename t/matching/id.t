#!/usr/bin/env perl
use lib '../lib';
use Mojo::Base -strict;
use Net::IPv6Addr;
use Data::Dumper::Concise;
use Flair::Util::Log;
use Flair::Util::Config;
use Flair::Util::Pg;

log_init('testlog.conf');
my $log = get_logger('Flair');
$log->info("$0 begins");

my $creader = Flair::Util::Config->new();
my $config  = $creader->get_config('flair.conf');
my $models  = Flair::Util::Pg->new->build_models($log, $config);
my $uuid_re = $models->{regex}->regex_by_name('uuid1');
my $clsid_re = $models->{regex}->regex_by_name('clsid');

my $text    = "d0229d40-1274-11e8-a427-3d01d7fc9aea";

say Dumper('uuid1',$uuid_re);

if ( $text =~ m/$uuid_re/g ) {
    say "MATCH UUID1";
}

say Dumper('clsid',$clsid_re);
if ( $text =~ m/$clsid_re/g ) {
    say "MATCH CSLID";
}

my $re1 = qr/
            [0-9a-f]{8}
            \-
            [0-9a-f]{4}
            \-
            11[ef][0-9a-f]
            \-
            [89ab][0-9a-f]{3}
            \-
            [0-9a-f]{12}
        /umsix;

if ( $text =~ m/$re1/g ) {
    say "What!?";
}

