#!/opt/perl/bin/perl

use Mojo::Base -strict;
use Test::Most;
use Data::Dumper::Concise;
use HTML::Element;

use lib '../lib';
use Flair::Parser;
use Flair::Util::Log;
use Flair::Util::LoadHashFile;
use Flair::Db;
use Flair::Config;

log_init('testlog.conf');
my $log = get_logger('Flair');
$log->info("$0 begins");

my $config = {
    scotapi => {
        user    => '',
        pass    => '',
        apikey  => '',
        uri_root    => '',
        insecure    => 1,
    },
    newdb    => {
        dbtype  => 'mysql',
        mysqluri => 'mysql://flair:flairrox!123@localhost/flairtest',
        model   => {
            regex   => {},
            metrics => {},
            admins  => {},
            jobs    => {},
        },
        migration   => '../etc/flair.mysql.sql',
    },
};

system("rm -f /var/flair/test.db");

my $lhf = Flair::Util::LoadHashFile->new();
my $migfile = $config->{newdb}->{migration};
my $db  = Flair::Db->new(log => $log, config  => $config->{newdb});
is (ref($db), "Flair::Db", "Got DB connection") or die "unable to connect to db";

ok ($db->dbh->migrations->from_file($migfile)->migrate(0)->migrate, 
    "Migrated database") or die "Unable to intialize database";

# need to populate regex table
populate_regex_table();

my $parser  = Flair::Parser->new(log => $log, db => $db, scot_external_hostname => 'scot.watermelon.com');
ok(defined $parser, "Parser instantiated") or die "Failed to instantiate parser";

my $test_data_dir   = "./parser_test_data";
opendir my $dir, $test_data_dir or die "Failed to open Directory: $!";
my @data_files      = readdir $dir;
closedir $dir;

# if filenames are listed on command line, use them
if ($ARGV[0]) {
    @data_files = @ARGV;
}

foreach my $df (@data_files) {
    next if $df =~ /\.{1,2}/;   # skipp . and ..
    my $fqn = join('/',$test_data_dir, $df);
    next if -d $fqn;

    $log->debug("== ==");
    $log->debug("== Testing $fqn ==");
    $log->debug("== ==");

    my $test    = $lhf->get_hash($fqn);
    my $edb     = {};
    my $fpos    = {};
    my $text    = $test->{text};
    my @new     = $parser->parse($text, $edb, $fpos);
    my $result  = join('', map { (ref $_) ? $_->as_HTML('') : $_ } @new);
    delete $edb->{cache};

    is ($result, $test->{expect}, "Flaired Text Correctly in $df")
    or xdiff($result, $test->{expect});

    cmp_deeply($edb, $test->{entities}, "EDB Correct in $df")
    or die "EDB Differs: ".Dumper($edb, $test);
}

done_testing();
exit 0;

sub hdiff {
    my $g   = shift;
    my $e   = shift;
    for (my $i = 0; $i < length($g); $i++) {
        if ( substr($g, $i, 1) eq substr($e, $i, 1) ) {
            print substr($g, $i, 1);
            next;
        }
        print "\n";
        say "[got] ".substr($g, $i);
        say "[exp] ".substr($e, $i);
        last;
    }
    die "Produced HTML differs";
}

sub xdiff {
    my $g   = shift;
    my $e   = shift;

    for (my $i = 0; $i < length($g); $i++) {
        my $gchar = substr($g, $i, 1);
        my $echar = substr($e, $i, 1);

        if ($gchar eq $echar) {
            print $gchar;
            next;
        }

        print "\n at char $i, test output differs from expected output\n";
        print "[test] = $gchar\n";
        print "[exp ] = $echar\n";
        last;
    }
    die "Produced HTML differs";
}

sub populate_regex_table {
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
                    SANDIA\\\[a-z0-9]+
                    \b
                },
                entity_type => 'suser',
                re_type     => 'local',
                re_group    => 'sandia',
                re_order    => 1002,
                multiword   => 1,
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
            {
                name        => 'cf_site',
                description => 'User defined entity regex',
                match       => q{/cfdocs/eCATT/},
                entity_type => 'cf_site',
                re_type     => 'udef',
                re_group    => 'udef',
                re_order    => 1009,
                multiword   => 0,
                active      => 1,
            },
    );

    foreach my $href (@ul_res) {
        $db->regex->create($href);
    }
}
    

    


