#!/opt/perl/bin/perl

use Mojo::Base -strict;
use Test::Most;
use Data::Dumper::Concise;
use Mojo::mysql;

use lib '../lib';
use Flair::Util::Log;
use Flair::Db;
use Flair::Regex;

log_init('testlog.conf');
my $log = get_logger('Flair');
$log->info("$0 begins");

my $dbcstr = 'flair:flairrox!123@localhost';
my $dbname = "flairtest";

my $config  = {
    newdb   => {
        dbtype      => 'mysql',
        mysqluri    => "mysql://$dbcstr/$dbname",
        model       => {
            regex   => {},
            metrics => {},
            admins  => {},
            jobs    => {},
        }, 
        migration   => "../etc/flair.mysql.sql",
    },
};

my $db  = Flair::Db->new(log => $log, config => $config->{newdb});
is (ref($db), "Flair::Db", "Got DB connection") or die "unable to create db object";

$db->dbh->migrations->from_file($config->{newdb}->{migration})->migrate(0)->migrate;

my $regex_util = Flair::Regex->new(
    db                      => $db,
    log                     => $log,
    scot_external_hostname  => 'scot.watermelon.com',
);

$regex_util->add_group('sandia');
$regex_util->add_group('udef');

# create some test udef and locals
my @ul_res  = (
        {
            name        => 'snumber',
            description => 'Find Sandia SNumbers',
            match       => q{
                \b
                ([sS][0-9]{6,7})
                \b
            },
            entity_type => 'snumber',
            re_type     => 'local',
            re_group    => 'sandia',
            re_order    => 1001,
            multiword   => 0,
            active      => 1,
        },
        {
            name        => 'suser',
            description => 'Find Sandia Usernames',
            match       => q{
                \b
                SANDIA\\\S+
                \b
            },
            entity_type => 'snumber',
            re_type     => 'local',
            re_group    => 'sandia',
            re_order    => 1002,
            multiword   => 0,
            active      => 1,
        },
        {
            name        => 'snlserver1',
            description => 'Find Sandia Server names',
            match       => q{
                \b
                as\d+snl(lx|tz|tc|tp|nt)
                \b
            },
            entity_type => 'sandiaserver',
            re_type     => 'local',
            re_group    => 'sandia',
            re_order    => 1003,
            multiword   => 0,
            active      => 1,
        },
        {
            name        => 'snlserver2',
            description => 'Find Sandia Server names',
            match       => q{
                \b
                as\d+mcs(lx|tz|tc|tp|nt)
                \b
            },
            entity_type => 'sandiaserver',
            re_type     => 'local',
            re_group    => 'sandia',
            re_order    => 1004,
            multiword   => 0,
            active      => 1,
        },
        {
            name        => 'fufoo',
            description => 'Find fufoo in text',
            match       => q{fufoo},
            entity_type => 'test_entity',
            re_type     => 'udef',
            re_group    => 'udef',
            re_order    => 1005,
            multiword   => 0,
            active      => 1,
        },
        {
            name        => 'closing dispo',
            description => 'Find closing dispo in text',
            match       => q{new closing dispo},
            entity_type => 'test_entity',
            re_type     => 'udef',
            re_group    => 'udef',
            re_order    => 1006,
            multiword   => 0,
            active      => 1,
        },
        {
            name        => 'sydney rox',
            description => 'Find sydney rox in text',
            match       => q{sydney rox},
            entity_type => 'test_entity',
            re_type     => 'udef',
            re_group    => 'udef',
            re_order    => 1007,
            multiword   => 0,
            active      => 1,
        },
        {
            name        => 'Apt32',
            description => 'Find Apt32 in text',
            match       => q{apt32},
            entity_type => 'threat-actor',
            re_type     => 'udef',
            re_group    => 'udef',
            re_order    => 1008,
            multiword   => 0,
            active      => 1,
        },
);

foreach my $href (@ul_res) {
    $db->regex->create($href);
}


my $core_re_count = scalar(@{$regex_util->core_regex_names});
my $udef_re_count = grep { $_->{re_group} eq 'udef' } @ul_res;
is ($udef_re_count, 4, "Correct number of udef");
my $sandia_re_count= grep { $_->{re_group} eq 'sandia'} @ul_res;
is ($sandia_re_count, 4, "Correct number of sandia");
my $total_re_count  = $core_re_count + $udef_re_count + $sandia_re_count;

is (ref($regex_util), "Flair::Regex", "Got Regex Utility object");

my @default_re_types = ('core', 'udef', 'local');
my @default_re_groups= ('core', 'udef', 'sandia');

cmp_bag($regex_util->re_types, \@default_re_types, "Got correct default re_types");
cmp_bag($regex_util->re_groups, \@default_re_groups, "Got correct default re_groups");

push @default_re_types, 'foo';
push @default_re_groups, 'bar';

$regex_util->add_type('foo');
$regex_util->add_group('bar');

cmp_bag($regex_util->re_types, \@default_re_types, "Got correct added re_types");
cmp_bag($regex_util->re_groups, \@default_re_groups, "Got correct added re_groups");

my @set = @{$regex_util->re_set};
# print Dumper(@set);
is (scalar(@set), $total_re_count, "Got correct number of regexes");

$regex_util->re_groups([]);
$regex_util->re_set($regex_util->get_re_set);
@set = @{$regex_util->re_set};
my $null_re_group_count = scalar(@set);

$regex_util->re_groups(undef);
$regex_util->re_set($regex_util->get_re_set);
@set = @{$regex_util->re_set};
my $undef_re_group_count = scalar(@set);

is ($undef_re_group_count, $null_re_group_count, "Empty array and undef group sets return same number of members");

# print Dumper(@set);
# print "Set has ".scalar(@set)." members\n";

done_testing();
