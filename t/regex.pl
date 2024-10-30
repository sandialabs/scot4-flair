#!/opt/perl/bin/perl
# use Regexp::Debugger;
use warnings;
no warnings qw(experimental::vlb);

my $re = qr{
        (
            (?:
                # one or more of these
                [\=a-z0-9!\#$%&'*+/?^_`{|}~-]+
                # zero or more of these
                (?:\.[\=a-z0-9!\#$%&'*+/?^_`{|}~-]+)*
            )
            @
            (?:
                (?!\d+\.\d+)
                (?=.{4,255})
                (?:
                    (?:[a-zA-Z0-9-]{1,63}(?<!-)\.)+
                    [a-zA-Z0-9-]{2,63}
                )
            )
        )
}xims;
my $text = <<'EOF';

Arbitrary text followed by a snippet of an email header:

To: "T B" <tbruner@sandia.gov>, "Foobar" <foo@bar.com>
MessageID: <adfadsfadsf@adsfasdf.com>

More text.

EOF

while ( $text =~ m/$re/g ) {

    my $pre     = substr($text, 0, $-[0]);
    my $match   = substr($text, $-[0], $+[0] - $-[0]);
    my $post    = substr($text, $+[0]);

    print "Pre     = $pre\n";
    print "Match   = $match\n";
    print "Pos     = $post\n";
}
