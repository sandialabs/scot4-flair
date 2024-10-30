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
    database    => {
        dbtype  => 'sqlite',
        uri     => 'file:/var/flair/test.db',
        model   => {
            regex   => {},
            metrics => {},
            admins  => {},
            jobs    => {},
        },
        migration   => '../etc/test.sqlite.sql',
    },
};

my $lhf = Flair::Util::LoadHashFile->new();

my $migfile = $config->{database}->{migration};
my $db  = Flair::Db->new(log => $log, config  => $config->{database});
is (ref($db), "Flair::Db", "Got DB connection") or die "unable to connect to db";
ok ($db->dbh->migrations->from_file($migfile)->migrate(0)->migrate, 
    "Migrated database") or die "Unable to intialize database";

my $parser  = Flair::Parser->new(log => $log, db => $db);
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
    or hdiff($result, $test->{expect});

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

    

    


