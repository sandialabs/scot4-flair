#!/opt/perl/bin/perl 

use Mojo::Base -strict;
use Test::Most;
use Data::Dumper::Concise;
use JSON;
use Storable qw(dclone);
use Log::Log4perl::Level;
use Digest::MD5 qw(md5_hex);

use lib '../lib';
use Flair::Db;
use Flair::Util::Log;

log_init('testlog.conf');
my $log = get_logger('Flair');
$log->info("$0 begins");
$log->level($TRACE);

my @configs  = (
    {
        dbtype  => 'sqlite',
        dbfile  => 'file:/var/flair/test.db',
        model   => {
        },
        migration   => '../etc/flair.sqlite.sql',
    },
);

my $target_type = {
    sqlite  => 'Mojo::SQLite',
    pg      => 'Mojo::Pg',
    mysql   => 'Mojo::mysql',
};

my $db;

foreach my $config (@configs) {

    $log->debug("Testing Config: ", {filter => \&Dumper, value => $config});
    say "Testing with Config: ".$config->{dbtype};

    $db  = Flair::Db->new(
        log     => $log,
        config  => $config,
    );
    is (ref($db), "Flair::Db", "Got a Db object");
    $db->dbh->migrations->from_file($config->{migration})->migrate(0)->migrate;
    is (ref($db->dbh), $target_type->{$config->{dbtype}}, "Got right type of DBH");


}

print $db->dbh->db->query('select * from apikeys');

my $apikeys = $db->apikeys;
my $result  = $apikeys->list({ fields => ['*'], where => undef });

print Dumper($result);

done_testing();
exit 0;



