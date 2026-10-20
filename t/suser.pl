use Data::Dumper::Concise;

my $restring = q{
    \b
    ([a-zA-Z0-9.\_\-]{1,15}\\\\[a-zA-Z0-9.\_\-\s]{1,104})
    \b
};
my $re = qr{$restring}xims;

print Dumper($re);

my $test = 'This SANDIA\foo user is dumb';

if ($test =~ /$re/) {
    print "yep! $1\n";
}
