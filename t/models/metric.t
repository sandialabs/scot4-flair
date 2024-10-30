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
    {
        dbtype  => 'sqlite',
        uri     => 'file:flairtest.db',
        model   => {
        },
        migration   => '../../etc/test.sqlite.sql',
    },
#    {
#        dbtype  => 'pg',
#        uri     => 'postgresql://flairtest:flair1234@localhost/flairtest',
#        model   => {
#        },
#        migration   => '../../etc/flair.pg.sql',
#    },
#    {
#        dbtype  => 'mysql',
#        uri     => 'mysql://flairtest:flair1234@localhost/flairtest',
#        model   => {
#        },
#        migration   => '../../etc/flair.mysql.sql',
#    },
);


my $dt  = DateTime->new({
    year    => 1998,
    month   => 6,
    day     => 20,
    hour    => 14,
});
my $dt2  = DateTime->new({
    year    => 1998,
    month   => 6,
    day     => 20,
    hour    => 15,
});

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

    my $model   = $db->metrics;

    my $result  = $model->add_metric("Foo", 1, $dt);
    my $metric  = $model->get_metric({
        year    => $dt->year,
        month   => $dt->month,
        day     => $dt->day,
        hour    => $dt->hour,
        metric  => "Foo",
    });
    say Dumper($metric);
    is ($metric->[0]->{value} +0, 1, "Got correct Metric") or die "incorrect metric";

    $result = $model->add_metric("Foo", 3, $dt);
    $metric  = $model->get_metric({
        year    => $dt->year,
        month   => $dt->month,
        day     => $dt->day,
        hour    => $dt->hour,
        metric  => "Foo",
    });
    is ($metric->[0]->{value}+0, 4, "Got correct Metric after integer addition");

    $result = $model->add_metric("Foo", 0.4, $dt);
    $metric  = $model->get_metric({
        year    => $dt->year,
        month   => $dt->month,
        day     => $dt->day,
        hour    => $dt->hour,
        metric  => "Foo",
    });
    is ($metric->[0]->{value}+0, 4.4, "Got correct Metric after float addition") or die "incorrect metric";

    $result     = $model->add_metric("Foo", 3, $dt2);
    $metric     = $model->get_metric({
        year    => $dt->year,
        month   => $dt->month,
        day     => $dt->day,
        metric  => "Foo"
    });
    is ($metric->[0]->{value}+0, 4.4, "Got correct metric[0]") or die "incorrect metric";
    is ($metric->[1]->{value}+0, 3, "Got correct metric[1]") or die "incorrect metric";

}
done_testing();
exit 0;



