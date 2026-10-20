#!/opt/perl/bin/perl

use Mojo::Base -strict;
use lib '../lib', './lib';
use Flair::Db;
use Flair::Config;
use Flair::Util::Log;
use Flair::Util::LoadHashFile;
use Data::Dumper::Concise;
use Log::Log4perl::Level;
use Try::Tiny;
use File::Slurp;
use feature 'say';

log_init('stdout.conf');
my $log = get_logger('Flair');
$log->level($TRACE);

$log->trace("Starting $0");

my $config      = build_config();
my $sqlconfig   = $config->{database};
my $myconfig    = $config->{newdb};
my $regex_file_dir = $config->{regex_set_dir};

my $db       = Flair::Db->new(
    log     => $log,
    config  => $myconfig,
);

my @useragents = read_file('../etc/useragents.txt');

foreach my $ua (@useragents) {
    my $re = {
        name    => 'useragent',
        description => 'browser user agent string',
        match   => $ua,
        entity_type => 'useragent',
        re_type => 'udef',
        re_group => 'useragent',
        re_order => 3000,
        multiword => 1,
    };
    my $href    = $db->regex->upsert_re($re);
}
