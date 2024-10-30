#!/opt/perl/bin/perl 

use Mojo::Base -strict;
use Test::Most;
use Data::Dumper::Concise;
use JSON;
use Storable qw(dclone);
use Log::Log4perl::Level;
use Digest::MD5 qw(md5_hex);
use DateTime;

use lib '../../lib';
use Flair::Db;
use Flair::Util::Log;

log_init('testlog.conf');
my $log = get_logger('Flair');
$log->info("$0 begins");
$log->level($TRACE);

my @configs  = (
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
    {
        dbtype  => 'sqlite',
        uri     => 'flairtest.db',
        model   => {
        },
        migration   => '../../etc/test.sqlite.sql',
    },
);

my $regex1_input = {
    name        => "foobar",
    description => "Find Foobar",
    match       => '/foobar/',
    entity_type => "foo_actor",
    regex_type  => 'core',
    re_order    => 1,
    multiword   => JSON::false,
};

my $regex2_input = {
    name        => "boombaz",
    description => "Find BoomBaz",
    match       => '/boombaz/',
    entity_type => "baz_actor",
    regex_type  => 'core',
    re_order    => 1,
    multiword   => JSON::false,
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
    my $target_type = 'Mojo::SQLite';
    is (ref($db->dbh), $target_type, "Got right type of DBH");

    my $model   = $db->regex;

    my $result1 = $model->create($regex1_input);
    my $expect1 = dclone($regex1_input);
    $expect1->{regex_id}    = 1;
    $expect1->{multiword}   = 0;
    $expect1->{updated}     = ignore();
    cmp_deeply($result1, $expect1, "Created Regex 1");

    my $result2 = $model->create($regex2_input);
    my $expect2 = dclone($regex2_input);
    $expect2->{regex_id}    = 2;
    $expect2->{multiword}   = 0;
    $expect2->{updated}     = ignore();
    cmp_deeply($result2, $expect2, "Created Regex 2");

    my $list_opts       = {
        fields      => ['*'],
        where       => undef,
        order       => { -desc => 'regex_id' },
        offset      => 0,
        limit       => undef,
    };
    my $expected_list   = [ $expect2, $expect1 ];
    my $list_result     = $model->list($list_opts);

    cmp_deeply($list_result, $expected_list, "listed as expected");

    my $patch   = { match => '/\b foobar \b/' };
    my $expect3 = dclone($expect1);
    $expect3->{match} = $patch->{match};
    my $result3 = $model->patch(1, $patch);
    cmp_deeply($result3, $expect3, "Patch Worked");

    my $count   = $model->count({});
    is($count->{count}, 2, "Correct Count");

    my $delete  = $model->delete(2);
    $count      = $model->count({});
    is($count->{count}, 1, "Deleted a Record");

    my $attempt = $model->fetch(2);
    is($attempt, undef, "Correctly unable to retrieve deleted regex");

    my @core    = $model->load_core_re();
    my @regexes = $model->build_flair_regexes();
    is (scalar(@regexes) -1, scalar(@core), "Got correct number of regexes");

    # TODO:
    # $model->regex_by_name("regex_name");
    # $model->upsert_re($href);
    # 
    my $exists = $model->regex_exists('/\b foobar \b/');
    is ($exists, 1, "Correctly found existing regex using regex");
    $exists = $model->regex_exists('zippywhippy');
    is ($exists, undef, "Correctly did not find a matching regex");

}
done_testing();
exit 0;



