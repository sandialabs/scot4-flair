#!/usr/bin/env perl
use lib '../../lib';
use Mojo::Base -strict;
use Net::IPv6Addr;
use Data::Dumper::Concise;
use Flair::Util::Log;
use Flair::Util::Config;
use Flair::Util::Pg;
# use Regexp::Debugger;

log_init('testlog.conf');
my $log = get_logger('Flair');
$log->info("$0 begins");

my $creader = Flair::Util::Config->new();
my $config  = $creader->get_config('flair.conf');
#my $models  = Flair::Util::Db->new->build_models($log, $config);
#my $re      = $models->{regex}->regex_by_name('message_id');

my $text    = ' &lt;CAEr1S5-HuU1MjnUQtqT6Ri-i2ZaYcTm_+cjf6mkmOgwGJHjPJA@mail.gmail.com&gt; ';
my $text2    = 'CAEr1S5-HuU1MjnUQtqT6Ri-i2ZaYcTm_+cjf6mkmOgwGJHjPJA@mail.gmail.com';
# say Dumper('message_id',$re);
# if ( $text =~ m/$re/g ) {
#     say "RE MATCH message_id";
# }

my $xre = qr/(
                (<|&lt;)?        # starts with < or &lt;
                (?:[^\s]*?)     # some nonblank chars
                @               # an @ seperator
                (?:[^\s]*?)     # some nonblank chars
                (>|&gt;)?       # ends with > or &gt;
        )/umsix;

if ( $text =~ m/$xre/g ) {
    say "XRE match\n";
}

if ($text2 =~ m/$xre/g) {
    say "text2 match\n";
}
