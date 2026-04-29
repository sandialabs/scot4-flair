#!/opt/perl/bin/perl

use Mojo::Base -strict;
use lib '../lib';
use Flair::Db;
use Flair::Util::Log;
use Data::Dumper::Concise;
use Log::Log4perl::Level;
use feature 'say';

log_init('testlog.conf');
my $log = get_logger('Flair');
$log->level($TRACE);

my $config = {
    dbtype  => 'sqlite',
    dbfile  => '/home/tbruner/flair.db',
    uri     => 'file:/home/tbruner/flair.db',
    model   => {},
};

my $db = Flair::Db->new(
    log     => $log,
    config  => $config,
);


foreach my $year (qw(2025)) {
    my $totals = $db->metrics->get_monthly_totals({year => $year });
    my $outname = "/home/tbruner/$year-2.stats.csv";
    open (my $fh, ">", $outname) or die "$!";
    my $header =  "metric,day,total\n";
    print $fh $header;
    foreach my $metric (sort keys %$totals) {
        foreach my $day (sort keys %{$totals->{$metric}}) {
            my $line = join(',', $metric, $day, $totals->{$metric}->{$day})."\n";
            print $fh $line;
        }
    }
    close($fh);
}


