#!/opt/perl/bin/perl 

use Mojo::Base -strict;
use Test::Most;
use Data::Dumper::Concise;
use JSON;
use Storable qw(dclone);
use Crypt::PBKDF2;
use Log::Log4perl::Level;

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
        dbfile  => '/var/flair/test.db',
        model   => {
        },
        migration   => '../../etc/test.sqlite.sql',
    },
    #    {
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

my $pbkdf2  = Crypt::PBKDF2->new(
    hash_class  => 'HMACSHA2',
    hash_args   => { sha_size => 512 },
    iterations  => 10000,
    salt_len    => 15,
);

my $admin1_input    = {
    username    => 'foobar',
    who         => 'Mr. Foo Bar, esq.',
    pwhash      => $pbkdf2->generate('boombaz'),
};
my $admin2_input    = {
    username    => 'scotty',
    who         => 'Mr. Scot Scot, IV',
    pwhash      => $pbkdf2->generate('coolpass'),
};

foreach my $config (@configs) {
    $log->debug("Testing Config: ", {filter => \&Dumper, value => $config});

    my $db  = Flair::Db->new(
        log     => $log,
        config  => $config,
    );
    is (ref($db), "Flair::Db", "Got a Db object");
    $db->dbh->migrations->from_file($config->{migration})->migrate(0)->migrate;
    my $target_type = {
        pg  => 'Mojo::Pg',
        mysql   => 'Mojo::mysql',
        sqlite  => 'Mojo::SQLite',
    };; 
    is (ref($db->dbh), $target_type->{$config->{dbtype}}, "Got right type of DBH");

    my $model   = $db->admins;
    my $result1 = $model->create($admin1_input);
    $log->debug("result:",{filter=>\&Dumper, value=>$result1});
    my $expect1 = dclone($admin1_input);
    $expect1->{admin_id}    = 1;
    $expect1->{updated}     = ignore();
    $expect1->{lastlogin}   = ignore();
    $expect1->{lastaccess}  = ignore();
    cmp_deeply($result1, $expect1, "Created Admin 1");

    my $result2 = $model->create($admin2_input);
    my $expect2 = dclone($admin2_input);
    $expect2->{admin_id}    = 2;
    $expect2->{updated}     = ignore();
    $expect2->{lastlogin}   = ignore();
    $expect2->{lastaccess}  = ignore();
    cmp_deeply($result2, $expect2, "Created Admin 2");

    my $fetch1_result   = $model->fetch(1);
    cmp_deeply($fetch1_result, $expect1, "Retrieved Admin 1");
    my $fetch2_result   = $model->fetch(2);
    cmp_deeply($fetch2_result, $expect2, "Retrieved Admin 2");

    my $list_opts   = {
        fields      => ['*'],
        where       => undef,
        order       => { -desc => 'admin_id' },
        offset      => 0,
        limit       => undef,
    };
    my $list_expect = [ $expect2, $expect1 ];
    my $list_result = $model->list($list_opts);
    cmp_deeply($list_result, $list_expect, "Listed admins as expected");

    my $patch   = { pwhash => $pbkdf2->generate('changedpassword')};
    my $expect3 = dclone($expect1);
       $expect3->{pwhash} = $patch->{pwhash};
       $expect3->{updated} = ignore();
    my $result3 = $model->patch(1, $patch);
    cmp_deeply($result3, $expect3, "Patch works");

    my $count   = $model->count({});
    is($count->{count}, 2, "Correct count");
    
    my $delete  = $model->delete(2);
    $count      = $model->count({});
    is($count->{count}, 1, "Deleted Record");

    my $attempt     = $model->fetch(2);
    is($attempt, undef, "Correctly failed to retrieve deleted row");

    sleep 1;

    my $lastlog_update  = $model->set_lastlogin('foobar');
    my $previous_ll     = $result3->{lastlogin};
    my $current_ll      = $lastlog_update->{lastlogin};
    ok($current_ll ne $previous_ll, "Last Login updated");

}
done_testing();
exit 0;



