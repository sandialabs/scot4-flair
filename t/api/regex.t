#!/opt/perl/bin/perl

use Mojo::Base -strict;
use Test::Most;
use Test::Mojo;
use Data::Dumper::Concise;
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
my $config = {
    database => {
        dbtype  => 'sqlite',
        dbfile  => 'file:/var/flair/test.db',
        model   => {},
        migration => '../../etc/test.sqlite.sql',
    },
    mode    => 'development',
    logconf => 'testlog.conf',
};

my $db  = Flair::Db->new(log=>$log, config=>$config->{database});
my $ddf  = $config->{database}->{migration};
$db->dbh->migrations->from_file($ddf)->migrate(0)->migrate;

my $t = Test::Mojo->new('Flair', $config);

$log->debug("INSERT TESTS ======================================");
my $regex_data = {
    name        => "Foobar",
    description => "Find Foobar in Text",
    match       => '/\b foobar \b/xims',
    entity_type => 'agent of chaos',
    regex_type  => 'core',
    re_order    => 1,
    multiword   => JSON::false,
};

my $expected = dclone($regex_data);
   $expected->{regex_id}   = 1;
   $expected->{updated}    = ignore();


$t->post_ok('/api/v1/regex' => $auth => json =>  $regex_data)
  ->status_is(201);
my $got = $t->tx->res->json;
$log->debug("GOT ",{filter => \&Dumper, value => $got});
cmp_deeply($got, $expected, "Created Regex");

# test against duplicated inserts
$t->post_ok('/api/v1/regex' => $auth => json => $regex_data)->status_is(409);

say Dumper($t->tx->res->json);
done_testing();
exit 0;



my $redata2 = {
    name        => "Boombaz",
    description => "Find boombaz in Text",
    match       => '/\b boombaz \b/xims',
    entity_type => 'agent of calm',
    regex_type  => 'core',
    re_order    => 1,
    multiword   => JSON::false,
};
my $expected2             = dclone($regex_data);
   $expected2->{regex_id} = 2;
   $expected2->{updated}  = ignore();

$t->post_ok('/api/v1/regex' => $auth => json =>  $regex_data)
  ->status_is(201);
my $got2 = $t->tx->res->json;
cmp_deeply($got2, $expected2, "Created another Regex");

$log->debug("LIST TESTS ======================================");
my $list_expected = [ $expected2, $expected ];

$t->get_ok("/api/v1/regex?limit=0&offset=10" => $auth)
    ->status_is(200);

my $gotlist =$t->tx->res->json;
cmp_deeply($gotlist, $list_expected, "List correct");


$log->debug("FETCH TESTS ======================================");
$t->get_ok("/api/v1/regex/1" => $auth)->status_is(200);
cmp_deeply($t->tx->res->json, $got, "Fetch 1 worked");

$t->get_ok("/api/v1/regex/2" => $auth)->status_is(200);
cmp_deeply($t->tx->res->json, $got2, "Fetch 2 worked");

$log->debug("UPDATE TESTS ======================================");
my $redata_updated = {
    name        => "Zoobar",
    description => "Find Zoobar in Text",
    match       => '/\b zoobar \b/xims',
    entity_type => 'agent of zeus',
    regex_type  => 'core',
    re_order    => 1,
    multiword   => JSON::false,
};

my $expected3 = dclone($redata_updated);
$expected3->{regex_id} = 1;
$expected3->{updated} = ignore();

$t->put_ok("/api/v1/regex/1" => $auth => json => $redata_updated)
    ->status_is(200);
cmp_deeply($t->tx->res->json, $expected3, "Update Worked");

$log->debug("PATCH TESTS ======================================");
my $redata_patch = {
    description => "Who is boombaz?",
    regex_type  => 'udef',
};

my $expected4 = dclone($expected3);
$expected4->{description} = $redata_patch->{description};
$expected4->{regex_type}  = $redata_patch->{regex_type};

$t->patch_ok("/api/v1/regex/1" => $auth => json => $redata_patch)
    ->status_is(200);
cmp_deeply($t->tx->res->json, $expected4, "Patch Worked");

$log->debug("DELETE TESTS ======================================");
$t->delete_ok("/api/v1/regex/1" => $auth)
    ->status_is(200);
cmp_deeply($t->tx->res->json, $expected4, "Got Deleted record");
$t->get_ok("/api/v1/regex/1" => $auth)->status_is(200);
is($t->tx->res->json, undef, "Record was removed");


$log->debug("COUNT TESTS ======================================");
$t->get_ok("/api/v1/regex/count"  => $auth => json => {})
    ->status_is(200)
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
