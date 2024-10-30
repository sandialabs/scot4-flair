#!/usr/bin/env perl
use lib '../../lib';
use Mojo::Base -strict;
use Net::IPv6Addr;
use Data::Dumper::Concise;
use Flair::Util::Log;
use Flair::Util::Config;
use Flair::Util::Pg;

#my $ip1 = Net::IPv6Addr->new('1762:0:0:0:0:B03:1:AF18');
#say Dumper($ip1);

#my $ip2 = Net::IPv6Addr->new('2001:41d0:2:9d17::');
#say Dumper($ip2);

my $re  = qr{(
    # first look for a suricata/snort format (ip:port)
    (?:
        # look for aaaa:bbbb:cccc:dddd:eeee:ffff:gggg:hhhh
        (?:
            (?:[A-F0-9]{1,4}:){7}[A-F0-9]{1,4}
        )
        # look for but dont capture a trailing :\d+
        (?=:[0-9]+)
    )
    # next try the rest of the crazy that is ipv6
    # thanks to autors of
    # https://learning.oreilly.com/library/view/regular-expressions-cookbook/9781449327453/c  h08s17.html
    |(?:
        # Mixed
        (?:
            # Non-compressed
            (?:[A-F0-9]{1,4}:){6}
            # Compressed with at most 6 colons
            |(?=(?:[A-F0-9]{0,4}:){0,6}
                (?:[0-9]{1,3}\.){3}[0-9]{1,3}  # and 4 bytes
                (?![:.\w])
            )
            # and at most 1 double colon
            (([0-9A-F]{1,4}:){0,5}|:)((:[0-9A-F]{1,4}){1,5}:|:)
            # Compressed with 7 colons and 5 numbers
            |::(?:[A-F0-9]{1,4}:){5}
        )
        # 255.255.255.
        (?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}
        # 255
        (?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])

        |# Standard
        (?:[A-F0-9]{1,4}:){7}[A-F0-9]{1,4}
        |# Compressed with at most 7 colons
        (?=(?:[A-F0-9]{0,4}:){0,7}[A-F0-9]{0,4}
            (?![:.\w])
        )  # and anchored
        # and at most 1 double colon
        (([0-9A-F]{1,4}:){1,7}|:)((:[0-9A-F]{1,4}){1,7}|:)
        # Compressed with 8 colons
        |(?:[A-F0-9]{1,4}:){7}:|:(:[A-F0-9]{1,4}){7}
    ) (?![:.\w]) # neg lookahead to "anchor"
    \b
)}xims;

# my $text = '2001:41d0:2:9d17:: ';
my $text = 'switch to 1762:0:0:0:0:b03:1:af18.';

if ($text =~ m/$re/g) {
    say "matched: $1";
}

exit 0;

log_init('testlog.conf');
my $log = get_logger('Flair');
$log->info("$0 begins");

my $creader = Flair::Util::Config->new();
my $config  = $creader->get_config('flair.conf');
my $models  = Flair::Util::Pg->new->build_models($log, $config);
my $regexes = $models->{regex}->build_flair_regexes();

my $tre;
foreach my $re (@$regexes) {
    next if ($re->{name} ne "ipv6");
    $tre = $re->{regex};
    say Dumper($tre);
    last;
}

if ( $text =~ m/$tre/g ) {
    say "db re matched";
}
say "------------";
say Dumper($re, $tre);
