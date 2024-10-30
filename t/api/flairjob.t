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
        dbfile  => 'file:/var/flair/test.db',
        model   => {},
        migration   => '../../etc/test.sqlite.sql',
    },
    mode  => 'development',
    logconf => 'testlog.conf',
};

my $db  = Flair::Db->new(log => $log, config => $config->{database});
my $ddf = $config->{database}->{migration};
$db->dbh->migrations->from_file($ddf)->migrate(0)->migrate;

my $t = Test::Mojo->new('Flair', $config);

# submit an Alertgroup
my $sub_ag_1 = {
    type    => 'alertgroup',
    id      => 100,
    data    => [
        { id => 200, columns => [ 'foo', 'boom' ], data => {foo => '["bar","baz"]', boom => '["10.10.10.1"]' } },
        { id => 201, columns => [ 'foo', 'boom', ], data => {foo => '["bir","biz"]', boom => '["20.20.20.2"]' } },
    ]
};

$t->post_ok('/api/v1/flair' => $auth => json => $sub_ag_1)
  ->status_is(202);

my $job_id = $t->tx->res->json->{job_id};

$log->debug("running perform_jobs");
$t->app->minion->perform_jobs;
$log->debug("after perform_jobs");

$t->get_ok("/api/v1/flair/$job_id" => $auth)->status_is(200)
  ->json_is('/alerts/0/entities/ipaddr/10.10.10.1', 1)
  ->json_is('/alerts/0/flair_data/boom','["<span class="entity ipaddr" data-entity-type="ipaddr" data-entity-value="10.10.10.1">10.10.10.1</span>"]')
  ->json_is('/alerts/1/entities/ipaddr/20.20.20.2', 1)
  ->json_is('/alerts/1/flair_data/foo', '["bir", "biz"]')
  ->json_is('/entities/ipaddr/10.10.10.1', 1)
  ->json_is('/entities/ipaddr/20.20.20.2', 1);
#say Dumper($t->tx->res->json);



# say Dumper($t->tx->res->json);
done_testing();
exit 0;
