#!/opt/perl/bin/perl

use Try::Tiny::Retry ':all';
my $i = 3;
my $foo = retry     { doit($i++); }
          catch     { print "caught exception = $_\n"; return;}
          on_retry  { print "Retrying...\n"; }
          delay_exp { 3, 10000}
          # delay { return if $_[0] >= 3; sleep 1 };
          ;
print "foo = $foo\n";

sub doit {
    my $i = shift;
    print "Doit($i)\n";
    die "Fudge!" if ($i > 2 and $i <5);
    return "wow";
}
