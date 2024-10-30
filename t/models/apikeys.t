#!/opt/perl/bin/perl 

use Mojo::Base -strict;
use Test::Most;
use Data::Dumper::Concise;
use JSON;
use Storable qw(dclone);
use Log::Log4perl::Level;
use Digest::MD5 qw(md5_hex);

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
    #{
    #    dbtype  => 'pg',
    #    uri     => 'postgresql://flairtest:flair1234@localhost/flairtest',
    #    model   => {
    #    },
    #    migration   => '../../etc/flair.pg.sql',
    #},
    #{
    #    dbtype  => 'mysql',
    #    uri     => 'mysql://flairtest:flair1234@localhost/flairtest',
    #    model   => {
    #    },
    #    migration   => '../../etc/flair.mysql.sql',
    #},
);

my $target_type = {
    sqlite  => 'Mojo::SQLite',
    pg      => 'Mojo::Pg',
    mysql   => 'Mojo::mysql',
};

my $apikey1_input    = {
    username    => 'foobar',
    key         => '11111111111111111111',
    flairjob    => JSON::true,
    regex_ro    => JSON::true,
    regex_crud  => JSON::true,
    metrics     => JSON::true,
};
my $apikey2_input    = {
    username    => 'boombaz',
    key         => '22222222222222222222',
    flairjob    => JSON::true,
    regex_ro    => JSON::false,
    regex_crud  => JSON::false,
    metrics     => JSON::false,
};
my $testapikey    = {
    apikey_id   => 1,
    updated     => ignore(),
    lastaccess  => ignore(),
    username    => 'flairtest',
    key         => 'flairtest123',
    flairjob    => 1,
    regex_ro    => 1,
    regex_crud  => 1,
    metrics     => 1,
};

foreach my $config (@configs) {

    $log->debug("Testing Config: ", {filter => \&Dumper, value => $config});
    say "Testing with Config: ".$config->{dbtype};

    my $db  = Flair::Db->new(
        log     => $log,
        config  => $config,
    );
    is (ref($db), "Flair::Db", "Got a Db object");
    $db->dbh->migrations->from_file($config->{migration})->migrate(0)->migrate;
    is (ref($db->dbh), $target_type->{$config->{dbtype}}, "Got right type of DBH");

    my $model   = $db->apikeys;

    my $result1 = $model->create($apikey1_input);
    my $expect1 = dclone($apikey1_input);
    $expect1->{apikey_id}   = 2;
    $expect1->{updated}     = ignore();
    $expect1->{lastaccess}  = ignore();
    $expect1->{flairjob}    = 1;
    $expect1->{regex_ro}    = 1;
    $expect1->{regex_crud}  = 1;
    $expect1->{metrics}     = 1;
    cmp_deeply($result1, $expect1, "Created Apikey 1") or die "Create Incorrect";

    my $result2 = $model->create($apikey2_input);
    my $expect2 = dclone($apikey2_input);
    $expect2->{apikey_id}    = 3;
    $expect2->{updated}     = ignore();
    $expect2->{lastaccess}  = ignore();
    $expect2->{flairjob}    = 1;
    $expect2->{regex_ro}    = 0;
    $expect2->{regex_crud}  = 0;
    $expect2->{metrics}     = 0;
    cmp_deeply($result2, $expect2, "Created Apikey 2") or die "Create Incorrect";

    my $fetch1_result   = $model->fetch(2);
    cmp_deeply($fetch1_result, $expect1, "Retrieved Apikey 1");
    my $fetch2_result   = $model->fetch(3);
    cmp_deeply($fetch2_result, $expect2, "Retrieved Apikey 2");

    my $list_opts   = {
        fields      => ['*'],
        where       => undef,
        order       => { -desc => 'apikey_id' },
        offset      => 0,
        limit       => undef,
    };
    my $list_expect = [ $expect2, $expect1, $testapikey ];
    my $list_result = $model->list($list_opts);
    cmp_deeply($list_result, $list_expect, "Listed apikeys as expected") or die "List Incorrect";

    my $patch   = { metrics => JSON::false, key => '3333' };
    my $expect3 = dclone($expect1);
       $expect3->{metrics} = 0;
       $expect3->{key} = $patch->{key};
    my $result3 = $model->patch(2, $patch);
    cmp_deeply($result3, $expect3, "Patch works") or die "Patch failed";

    my $count   = $model->count({});
    is($count->{count}, 3, "Correct count");
    
    my $delete  = $model->delete(3);
    $count      = $model->count({});
    is($count->{count}, 2, "Deleted Record") or die "delete failed";

    my $attempt     = $model->fetch(3);
    is($attempt, undef, "Correctly failed to retrieve deleted row");

    my $key = $model->get_key($expect3->{key});
    cmp_deeply($key, $expect3, "Got by Key") or die "failed to get by key";

}
done_testing();
exit 0;



