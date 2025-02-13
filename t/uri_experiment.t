#!/opt/perl/bin/perl

use Mojo::Base -strict;
use Test::Most;
use Data::Dumper::Concise;
use HTML::Element;

use lib '../lib';
use Flair::Regex;
use Flair::Util::Log;
use Flair::Util::LoadHashFile;
use Flair::Db;
use Flair::Config;

log_init('testlog.conf');
my $log = get_logger('Flair');
$log->info("$0 begins");

my $regexes = Flair::Regex->new();

my $uri = "This is a uri https://scot.watermelon.com/#/entity/123 and this is not";
my $rehash  = $regexes->uri;
my $re = $rehash->{regex};
my ($pre, $match, $post) = extract($uri, $re);
output($uri, $re, $pre, $match, $post);

done_testing();
exit 0;

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



