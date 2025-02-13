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

my $auth = { authorization => 'apikey flairtest123' };
my $config = {
    database    => {
        dbtype  => 'sqlite',
        uri     => 'file:/var/flair/test.db',
        model   => {},
        migration   => '../../etc/test.sqlite.sql',
    },
    mode    => 'development',
    logconf => 'testlog.conf',
};

my $db  = Flair::Db->new(log => $log, config => $config->{database});
my $ddf = $config->{database}->{migration};
$db->dbh->migrations->from_file($ddf)->migrate(0)->migrate;

$ENV{'S4FLAIR_DB_FILE'} = $config->{database}->{uri};
$ENV{'S4FLAIR_DB_URI'} = $config->{database}->{uri};
$ENV{'S4FLAIR_DB_MIGRATION'} = $config->{database}->{migration};

my $t = Test::Mojo->new('Flair', $config);

$log->debug("INSERT TESTS ======================================");
my $metric_data = {
    year    => 2002,
    month   => 4,
    day     => 4,
    hour    => 8,
    metric  => 'hours on the job',
    value   => 1,
};

my $expected = dclone($metric_data);
   $expected->{metric_id}   = 1;

$t->post_ok('/api/v1/metrics' => $auth => json =>  $metric_data)->status_is(201);
my $got = $t->tx->res->json;
cmp_deeply($got, $expected, "Created Status");

# say Dumper($got);
# done_testing();
# exit 0;

my $metric_data2 = {
    year    => 2002,
    month   => 4,
    day     => 4,
    hour    => 9,
    metric  => 'hours on the job',
    value   => 1,
};
my $expected2             = dclone($metric_data2);
   $expected2->{metric_id} = 2;

$t->post_ok('/api/v1/metrics' => $auth => json =>  $metric_data2)->status_is(201);
my $got2 = $t->tx->res->json;
cmp_deeply($got2, $expected2, "Created another Status");

$log->debug("LIST TESTS ======================================");
my $list_expected = [ $expected2, $expected ];

$t->get_ok("/api/v1/metrics?limit=0&offset=10" => $auth)->status_is(200);
my $gotlist =$t->tx->res->json;
cmp_deeply($gotlist, $list_expected, "List correct");


$log->debug("FETCH TESTS ======================================");
$t->get_ok("/api/v1/metrics/1" => $auth)->status_is(200);
cmp_deeply($t->tx->res->json, $got, "Fetch 1 worked");

$t->get_ok("/api/v1/metrics/2" => $auth)->status_is(200);
cmp_deeply($t->tx->res->json, $got2, "Fetch 2 worked");

$log->debug("UPDATE TESTS ======================================");
my $metric_update = {
    year    => 2002,
    month   => 4,
    day     => 4,
    hour    => 8,
    metric  => 'foobars',
    value   => 2,
};

my $expected3 = dclone($metric_update);
$expected3->{metric_id} = 1;

$t->put_ok("/api/v1/metrics/1" => $auth => json => $metric_update)->status_is(200);
cmp_deeply($t->tx->res->json, $expected3, "Update Worked");

$log->debug("PATCH TESTS ======================================");
my $metric_patch = {
    metric  => 'boombazs',
    value   => 3,
};

my $expected4 = dclone($expected3);
   $expected4->{metric} = $metric_patch->{metric};
   $expected4->{value}  = $metric_patch->{value};

$t->patch_ok("/api/v1/metrics/1" => $auth => json => $metric_patch)->status_is(200);
cmp_deeply($t->tx->res->json, $expected4, "Patch Worked");


$log->debug("DELETE TESTS ======================================");
$t->delete_ok("/api/v1/metrics/1" => $auth)->status_is(200);
cmp_deeply($t->tx->res->json, $expected4, "Got Deleted record");
$t->get_ok("/api/v1/metrics/1" => $auth)->status_is(200);
is($t->tx->res->json, undef, "Record was removed");


$log->debug("COUNT TESTS ======================================");
$t->get_ok("/api/v1/metrics/count" => $auth => json => {})->status_is(200)
    ->json_is('/count' => 1, "Correct count");


# say Dumper($t->tx->res->json);
done_testing();
exit 0;



sub find_rel_dir {
    my $target = shift;
    my @path    = ();

    while (not -r join('/', @path, $target)) {
        push @path, '..';
    }
    return join('/', @path, $target);
}
