my $string = "This is https://scot.watermelon.com/#/event/123 the event";

my $re  = qr(
    \b
    (
        (.+)://([a-z]+)/(.*)
    )
    \b
)xims;

my ($pre, $match, $post) = extract($string, $re);

output($string, $re, $pre, $match, $post);

sub extract {
    my $text    = shift;
    my $re      = shift;
    while ($text       =~ m/$re/g) {;
        my $pre = substr($text, 0, $-[0]);
        my $m   = substr($text, $-[0], $+[0] - $-[0]);
        my $post = substr($text, $+[0]);

        return $pre, $m, $post;
    }
}

sub output {
    my $text = shift;
    my $re  = shift;
    my $pre = shift;
    my $match   = shift;
    my $post    = shift;

    print "----\n";
    print "$text\n";
    print "----\n";
    print "$re\n";
    print "----\n";
    print "pre   = $pre\n";
    print "match = $match\n";
    print "post  = $post\n\n";
}
