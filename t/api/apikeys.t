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

my $auth    = {authorization => 'apikey flairtest123'};
my $config  = {
  database => {
      dbtype  => 'sqlite',
      dbfile  => 'file:/var/flair/test.db',
      model   => {},
      migration   => '../../etc/test.sqlite.sql',
  },
  mode  => 'development',
  logconf => 'testlog.conf',
};

my $db  = Flair::Db->new(
    log     => $log,
    config  => $config->{database},
);

# $ENV{MOJO_MIGRATIONS_DEBUG} = 1;
my $ddf = $config->{database}->{migration};
$log->debug("applying database migrations from $ddf");

$db->dbh->migrations->from_file($ddf)->migrate(0)->migrate;

my $t = Test::Mojo->new('Flair', $config);

##
## test the creation of an apikey via the api
## 

my $apikey_data = {
    username    => 'foobar',
    key         => '11111111111111111111111111',
    flairjob    => JSON::true,
    regex_ro    => JSON::true,
    regex_crud  => JSON::true,
    metrics      => JSON::true,
};

my $expected = dclone($apikey_data);
$expected->{id} = 2;

$log->debug("INSERT TESTS ======================================");

# NOTE: only testing some of the returned keys
# because json_is forces the expected value into a string
# and this messes up the booleans above.  Also, updated
# field is set at insert time and I do not have an easy
# way to see if we are "close"

$t->post_ok('/api/v1/apikeys' => $auth => json =>  $apikey_data)
  ->status_is(201)
  ->json_is('/apikey_id'    => 2, "Correct apikey_id")
  ->json_is('/key'          => $apikey_data->{key}, "Correct key")
  ->json_is('/username'     => $apikey_data->{username}, "Correct Username");

say Dumper($t->tx->res->json);
done_testing();
exit 0;

my $apikeydata2 = {
    username    => 'zoobar',
    key         => '2222222222222222222222222',
    flairjob    => JSON::true,
    regex_ro    => JSON::false,
    regex_crud  => JSON::false,
    metrics      => JSON::false,

};
my $expected2 = dclone($apikeydata2);
$expected2->{id} = 3;
$t->post_ok('/api/v1/apikeys' => json =>  $apikeydata2)
  ->status_is(201)
  ->json_is('/apikey_id'    => 2, "Correct apikey_id")
  ->json_is('/key'          => $apikeydata2->{key}, "Correct key")
  ->json_is('/username'     => $apikeydata2->{username}, "Correct Username");

my $list_expected = [ $expected2, $expected ];
$log->debug("LIST TESTS ======================================");
$t->get_ok("/api/v1/apikeys?limit=0&offset=10")
    ->status_is(200)
    ->json_is('/0/apikey_id'    => 2, "Apikey 0 id correct")
    ->json_is('/0/key'  => $apikeydata2->{key}, "Apikey 0 key correct")
    ->json_is('/1/apikey_id'    => 1, "Apikey 1 id correct")
    ->json_is('/1/key'  => $apikey_data->{key}, "Apikey 1 key correct");


$log->debug("FETCH TESTS ======================================");
$t->get_ok("/api/v1/apikeys/1")
  ->status_is(200)
  ->json_is('/apikey_id'    => 1, "Correct apikey_id")
  ->json_is('/key'          => $apikey_data->{key}, "Correct key")
  ->json_is('/username'     => $apikey_data->{username}, "Correct Username");


$t->get_ok("/api/v1/apikeys/2")
  ->status_is(200)
  ->json_is('/apikey_id'    => 2, "Correct apikey_id")
  ->json_is('/key'          => $apikeydata2->{key}, "Correct key")
  ->json_is('/username'     => $apikeydata2->{username}, "Correct Username");

my $redata_updated = {
    username    => 'foobar',
    key         => '91111111111111111111111111',
    flairjob    => JSON::false,
    regex_ro    => JSON::true,
    regex_crud  => JSON::false,
    metrics     => JSON::false,
};

my $expected3 = dclone($redata_updated);
$expected3->{id} = 1;

$log->debug("UPDATE TESTS ======================================");
$t->put_ok("/api/v1/apikeys/1" => json => $redata_updated)
  ->status_is(200)
  ->json_is('/apikey_id'    => 1, "Correct apikey_id")
  ->json_is('/key'          => $redata_updated->{key}, "Correct key");

#print Dumper($t->tx->res->json), "\n";
#done_testing();
#exit 0;

my $redata_patch = {
    username    => 'boombaz',
    key         => '11111111111111111111111111',
};

my $expected4 = dclone($expected3);
$expected4->{username}  = $redata_patch->{username};
$expected4->{key}       = $redata_patch->{key};

$log->debug("PATCH TESTS ======================================");
$t->patch_ok("/api/v1/apikeys/1" => json => $redata_patch)
    ->status_is(200)
    ->json_is('/username' => $expected4->{username}, "username updated")
    ->json_is('/key' => $expected4->{key}, "Key updated");


$log->debug("DELETE TESTS ======================================");
$t->delete_ok("/api/v1/apikeys/1")
    ->status_is(200)
    ->json_is('/apikey_id' => 1, "Got deleted id");
$t->get_ok("/api/v1/apikeys/1")
  ->status_is(200)
  ->json_is('' => undef, "deleted item not found");

$log->debug("COUNT TESTS ======================================");
$t->get_ok("/api/v1/apikeys/count" => json => {})
    ->status_is(200)
    ->json_is('' => { count => 1 }, "Correct Number of rows left");


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
