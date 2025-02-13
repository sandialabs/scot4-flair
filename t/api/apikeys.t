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
      uri     => 'file:/var/flair/test.db',
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

$ENV{'S4FLAIR_DB_FILE'} = $config->{database}->{uri};
$ENV{'S4FLAIR_DB_URI'} = $config->{database}->{uri};
$ENV{'S4FLAIR_DB_MIGRATION'} = $config->{database}->{migration};

my $t = Test::Mojo->new('Flair', $config);

##
## test the creation of an apikey via the api
## 

my $apikey_data = {
    username    => 'foobar',
    apikey      => '11111111111111111111111111',
    flairjob    => JSON::true,
    regex_ro    => JSON::true,
    regex_crud  => JSON::true,
    metrics     => JSON::true,
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
  ->json_is('/apikey'       => $apikey_data->{apikey}, "Correct key")
  ->json_is('/username'     => $apikey_data->{username}, "Correct Username");

  # say Dumper($t->tx->res->json);
  # done_testing();
  # exit 0;

my $apikeydata2 = {
    username    => 'zoobar',
    apikey         => '2222222222222222222222222',
    flairjob    => JSON::true,
    regex_ro    => JSON::false,
    regex_crud  => JSON::false,
    metrics      => JSON::false,

};
my $expected2 = dclone($apikeydata2);
$expected2->{id} = 3;
$t->post_ok('/api/v1/apikeys' => $auth => json =>  $apikeydata2)
  ->status_is(201)
  ->json_is('/apikey_id'    => 3, "Correct apikey_id")
  ->json_is('/apikey'       => $apikeydata2->{apikey}, "Correct key")
  ->json_is('/username'     => $apikeydata2->{username}, "Correct Username");

my $list_expected = [ $expected2, $expected ];
$log->debug("LIST TESTS ======================================");
$t->get_ok("/api/v1/apikeys?limit=0&offset=10" => $auth )
    ->status_is(200)
    ->json_is('/0/apikey_id'    => 3, "Apikey 0 id correct")
    ->json_is('/0/apikey'       => $apikeydata2->{apikey}, "Apikey 0 key correct")
    ->json_is('/1/apikey_id'    => 2, "Apikey 1 id correct")
    ->json_is('/1/apikey'       => $apikey_data->{apikey}, "Apikey 1 key correct");


$log->debug("FETCH TESTS ======================================");
$t->get_ok("/api/v1/apikeys/2" => $auth )
  ->status_is(200)
  ->json_is('/apikey_id'    => 2, "Correct apikey_id")
  ->json_is('/apikey'       => $apikey_data->{apikey}, "Correct key")
  ->json_is('/username'     => $apikey_data->{username}, "Correct Username");


$t->get_ok("/api/v1/apikeys/3" => $auth)
  ->status_is(200)
  ->json_is('/apikey_id'    => 3, "Correct apikey_id")
  ->json_is('/apikey'       => $apikeydata2->{apikey}, "Correct key")
  ->json_is('/username'     => $apikeydata2->{username}, "Correct Username");

my $redata_updated = {
    username    => 'foobar',
    apikey      => '91111111111111111111111111',
    flairjob    => JSON::false,
    regex_ro    => JSON::true,
    regex_crud  => JSON::false,
    metrics     => JSON::false,
};

my $expected3 = dclone($redata_updated);
$expected3->{id} = 2;

$log->debug("UPDATE TESTS ======================================");
$t->put_ok("/api/v1/apikeys/2"  => $auth => json => $redata_updated)
  ->status_is(200)
  ->json_is('/apikey_id'        => 2, "Correct apikey_id")
  ->json_is('/apikey'           => $redata_updated->{apikey}, "Correct key");

my $redata_patch = {
    username    => 'boombaz',
    apikey      => '11111111111111111111111111',
};

my $expected4              = dclone($expected3);
$expected4->{username}     = $redata_patch->{username};
$expected4->{apikey}       = $redata_patch->{apikey};

$log->debug("PATCH TESTS ======================================");
$t->patch_ok("/api/v1/apikeys/2" => $auth => json => $redata_patch)
    ->status_is(200)
    ->json_is('/username' => $expected4->{username}, "username updated")
    ->json_is('/apikey'   => $expected4->{apikey}, "Key updated");

#print Dumper($t->tx->res->json), "\n";
#done_testing();
#exit 0;


$log->debug("DELETE TESTS ======================================");
$t->delete_ok("/api/v1/apikeys/2" => $auth => json => {})
    ->status_is(200)
    ->json_is('/apikey_id' => 2, "Got deleted id");

$t->get_ok("/api/v1/apikeys/2" => $auth )
  ->status_is(200)
  ->json_is('' => undef, "deleted item not found");

$log->debug("COUNT TESTS ======================================");
$t->get_ok("/api/v1/apikeys/count" => $auth )
    ->status_is(200)
    ->json_is('' => { count => 2 }, "Correct Number of rows left");


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
