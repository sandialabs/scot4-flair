#!/opt/perl/bin/perl

use Mojo::Base -strict;
use Test::Most;
use Data::Dumper::Concise;
use Test::Mojo;
use Storable qw(dclone);
use JSON;
use Log::Log4perl::Level;

use lib '../../lib';
use Flair::Db;
use Flair::Util::Log;

log_init('testlog.conf');
my $log = get_logger('Flair');
$log->info("$0 begins");
$log->level($TRACE);

my $auth  = { authorization => 'apikey flairtest123' };
my $config  = {
    database  => {
        dbtype  => 'sqlite',
        dbfile  => '/var/flair/test.db',
        uri     => 'file:/var/flair/test.db',
        model   => {},
        migration   => '../../etc/test.sqlite.sql',
    },
    mode  => 'development',
    logconf => 'testlog.conf',
};

my $db  = Flair::Db->new(log => $log, config => $config->{database});
my $ddf = $config->{database}->{migration};
$db->dbh->migrations->from_file($ddf)->migrate(0)->migrate;

$ENV{'S4FLAIR_DB_FILE'} = $config->{database}->{dbfile};
$ENV{'S4FLAIR_DB_URI'} = $config->{database}->{uri};
$ENV{'S4FLAIR_DB_MIGRATION'} = $config->{database}->{migration};
$ENV{S4FLAIR_JOB_TEST} = 1;

my $t = Test::Mojo->new('Flair');

# submit an a Flairjob for an alertgroup
my $ag_1 = {
    id      => 100,
    type    => 'alertgroup',
    data    => {
      alerts => [
        { 
          id => 200, 
          row => {foo => '["bar","baz"]', boom => '["10.10.10.1"]' } 
        },
        { 
          id => 201, 
          row => {foo => '["bir","biz"]', boom => '["20.20.20.2"]' } },
      ],
    },
};

$t->post_ok('/api/v1/flair' => $auth => json => $ag_1)
  ->status_is(202);

my $job_id = $t->tx->res->json->{job_id};

$log->debug("running perform_jobs");
$t->app->minion->perform_jobs;
$log->debug("after perform_jobs");


$t->get_ok("/api/v1/flair/$job_id" => $auth)->status_is(200)
  ->json_is('/alerts/0/entities/ipaddr/10.10.10.1', 1)
  ->json_is('/alerts/0/flair_data/boom/0','<span class="entity ipaddr" data-entity-type="ipaddr" data-entity-value="10.10.10.1">10.10.10.1</span>')
  ->json_is('/alerts/1/flair_data/boom/0','<span class="entity ipaddr" data-entity-type="ipaddr" data-entity-value="20.20.20.2">20.20.20.2</span>')
  ->json_is('/alerts/1/flair_data/foo/0', "bir")
  ->json_is('/alerts/1/flair_data/foo/1', "biz")
  ->json_is('/entities/ipaddr/10.10.10.1', 1)
  ->json_is('/entities/ipaddr/20.20.20.2', 1);
  #
  # say Dumper($t->tx->res->json);

my $sub_ag_1 = {
    id      => 100,
    type    => 'alertgroup',
    object  => {
      full_alert_data => [
        { 
          id => 200, 
          row => {foo => '["bar","baz"]', boom => '["10.10.10.1"]' } 
        },
        { 
          id => 201, 
          row => {foo => '["bir","biz"]', boom => '["20.20.20.2"]' } },
      ],
    },
};
my $sub_ag_2  = {
    id      => 101,
    type    => 'alertgroup',
    object  => {
      full_alert_data => [
        { 
          id => 204, 
          row => { todd => ['toad'], sydney => ['skidknee'], maddox => ['mhuz'] },
        },
        { 
          id => 205, 
          row => { todd => ['tidd'], sydney => ['kiki'], maddox =>['madmax'] },
        },
      ],
    },
};

my @bulk_data = (
    $sub_ag_1,
    $sub_ag_2,
  );

my $bulk = {
  targets => [
    { type => "alertgroup", id => 101 },
    { type => "alertgroup", id => 100 },
  ],
  test_data => \@bulk_data,
};

$t->post_ok('/api/v1/bulkflair' => $auth => json => $bulk)
  ->status_is(202);

$log->debug("running perform_jobs");
$t->app->minion->perform_jobs;
$log->debug("after perform_jobs");

say Dumper($t->tx->res->json);
done_testing();
exit 0;
