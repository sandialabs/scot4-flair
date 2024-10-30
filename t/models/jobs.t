#!/opt/perl/bin/perl 

use Mojo::Base -strict;
use Test::Most;
use Data::Dumper::Concise;
use JSON;
use Storable qw(dclone);
use Log::Log4perl::Level;
use Digest::MD5 qw(md5_hex);
use DateTime;

use lib '../../lib';
use Flair::Db;
use Flair::Util::Log;

log_init('testlog.conf');
my $log = get_logger('Flair');
$log->info("$0 begins");
$log->level($TRACE);

my @configs  = (
    {
        dbtype  => 'sqlite',
        uri     => 'flairtest.db',
        model   => {
        },
        migration   => '../../etc/test.sqlite.sql',
    },
);



foreach my $config (@configs) {

    $log->debug("Testing Config: ", {filter => \&Dumper, value => $config});
    say "Testing with Config: ".$config->{dbtype};

    my $db  = Flair::Db->new(
        log     => $log,
        config  => $config,
    );
    is (ref($db), "Flair::Db", "Got a Db object");
    $db->dbh->migrations->from_file($config->{migration})->migrate(0)->migrate;
    my $target_type = 'Mojo::SQLite';
    is (ref($db->dbh), $target_type, "Got right type of DBH");

    my $model   = $db->jobs;


}
done_testing();
exit 0;



