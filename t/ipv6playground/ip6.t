#!/usr/bin/env perl

use lib '../../lib';
use Mojo::Base -strict;
use Net::IPv6Addr;
use Data::Dumper::Concise;

my @regexes = (
    {
        name    => 'suricata',
        regex   => qr{
                    (?:
                        (?:
                            (?:[A-F0-9]{1,4}:){7}[A-F0-9]{1,4}
                        )
                        (?::[0-9]+)
                    )
        }xims,
    },
    {
        name    => 'standard',
        regex   => qr{
                    (?:[A-F0-9]{1,4}:){7}[A-F0-9]{1,4}
        }xims,
    },
    {
        name    => 'compressed',
        regex   => qr{
            (?=
                (?:[A-Z0-9]{0,4}:){0,7}[A-F0-9]{0,4}(?![:\w])
            )
            (([0-9A-F]{1,4}:){1,7}|:)((:[0-9A-F]{1,4}){1,7}|:)
        }xims,
    },
    {
        name    => 'cmp8colo',
        regex   => qr{
            (?:[A-F0-9]{1,4}:){7}:|:(:[A-F0-9]{1,4}){7}(?![:\w])
        }xims,
    },
    {
        name    => 'mixed',
        regex   => qr{
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
        }xims,
    },
);

my @data    = (
    {
        text        => 'before 1762::b03:1:af18 after',
        suricata    => 0,
        standard    => 0,
        compressed  => 1,
        cmp8colo   => 0,
        mixed       => 0,
    },
    {
        text    => 'before 1762::b03:1:af18. after',
        suricata    => 0,
        standard    => 0,
        compressed  => 1,
        cmp8colo   => 0,
        mixed       => 0,
    },
    {
        text    => '1762:0:0:0:0:B03:1:AF18',
        suricata    => 0,
        standard    => 1,
        compressed  => 1,
        cmp8colo   => 0,
        mixed       => 0,
    },
    {
        text    => '1762:0:0:0:0:B03:1:AF18.',
        suricata    => 0,
        standard    => 1,
        compressed  => 1,
        cmp8colo   => 0,
        mixed       => 0,
    },
    {
        text    => '1762:0:0:0:0:B03:1:AF18:8080',
        suricata    => 1,
        standard    => 0,
        compressed  => 0,
        cmp8colo   => 0,
        mixed       => 0,
    },
    {
        text    => 'this 1762:0:0:0:0:B03:1:AF18 stinks',
        suricata    => 0,
        standard    => 1,
        compressed  => 0,
        cmp8colo   => 0,
        mixed       => 0,
    },
    {
        text    => 'this 1762:0:0:0:0:B03:1:AF18. also stinks',
        suricata    => 0,
        standard    => 1,
        compressed  => 0,
        cmp8colo   => 0,
        mixed       => 0,
    },
    {
        text    => '2001:41d0:2:9d17::',
        suricata    => 0,
        standard    => 0,
        compressed  => 1,
        cmp8colo   => 0,
        mixed       => 0,
    },
    {
        text    => '2001:41d0:2:9d17:: .',
        suricata    => 0,
        standard    => 0,
        compressed  => 1,
        cmp8colo   => 0,
        mixed       => 0,
    },
    {
        text    => 'Foo 2001:41d0:2:9d17:: bar',
        suricata    => 0,
        standard    => 0,
        compressed  => 1,
        cmp8colo   => 0,
        mixed       => 0,
    },
    {
        text    => 'Foo 2001:41d0:2:9d17::.',
        suricata    => 0,
        standard    => 0,
        compressed  => 1,
        cmp8colo   => 0,
        mixed       => 0,
    },
    {
        text    => '0:0:0:0:0:ffff:192.1.56.10 looks weird',
        suricata    => 0,
        standard    => 0,
        compressed  => 0,
        cmp8colo    => 0,
        mixed       => 1,
    },
    {
        text    => 'so does: ::ffff:192.1.56.10/96',
        suricata    => 0,
        standard    => 0,
        compressed  => 0,
        cmp8colo    => 0,
        mixed       => 1,
    },
);

foreach my $href (@data) {
    my $text = $href->{text};
    say "---- $text";
    printf " "x10 . " Expected  Got\n";

    my $worked = 0;

    foreach my $rehref (@regexes) {
        my $name = $rehref->{name};

        printf "%10s %1s         ",$name, $href->{$name};

        if ( $text =~ m/$rehref->{regex}/g ) {
            $worked++;
            say "1";
        }
        else {
            say "0";
        }
    }
    print "--------------- ";
    if ($worked) {
        say "MATCHED!";
    }
    else {
        say "NO MATCH";
    }
    say "";
}
