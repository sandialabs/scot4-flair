#!/opt/perl/bin/perl
# use Regexp::Debugger;
use warnings;
no warnings qw(experimental::vlb);

# my $re = qr{b\&h photo}xms;
my $re = qr{(\Qb&amp;h photo\E)}xims;
my $text = <<'EOF';

Go to b&amp;h photo and buy cameras

EOF

while ( $text =~ m/$re/g) {
    print "$1\n";
}
