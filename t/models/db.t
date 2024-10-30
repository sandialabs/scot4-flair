#!/opt/perl/bin/perl

use Mojo::Base -strict;
use Test::Most;
use Data::Dumper::Concise;
use Digest::MD5 qw(md5_hex);
use JSON;
use Storable qw(dclone);

use lib '../../lib';
use Flair::Db;
use Flair::Util::Log;


log_init('testlog.conf');
my $log = get_logger('Flair');
$log->info("$0 begins");

my $config1 = {
    uri     => 'flairtest.db',
    dbtype  => 'sqlite',
};

my $db1 = Flair::Db->new(log => $log, config => $config1);
my $dbh1 = $db1->dbh;

is(ref($dbh1), 'Mojo::SQLite', "Build correct DBH for SQLite");
$dbh1->migrations->from_file('../../etc/flair.sqlite.sql')->migrate(0)->migrate;

# test postgres first
my $config   = {
    uri => 'postgresql://flairtest:flair1234@localhost/flairtest',
    dbtype => 'pg'
};

#my $db = Flair::Db->new(log => $log, config => $config);
#my $dbh = $db->dbh;
#
#is(ref($dbh), "Mojo::Pg", "Build correct DBH for Postgres");
#
#$dbh->migrations->from_file('../../etc/flair.pg.sql')->migrate(0)->migrate;
#
#
#my $config2   = {
#    uri => 'mysql://flairtest:flair1234@localhost/flairtest',
#    dbtype => 'mysql'
#};
#
#my $db2 = Flair::Db->new(log => $log, config => $config2);
#my $dbh2 = $db2->dbh;
#
#is(ref($dbh2), "Mojo::mysql", "Built correct DBH for Mysql");
#
#$dbh2->migrations->from_file('../../etc/flair.mysql.sql')->migrate(0)->migrate;

done_testing();
exit 0;
