#!/opt/perl/bin/perl

use Mojo::Base -strict;
use lib '../lib', './lib';
use Flair::Db;
use Flair::Config;
use Flair::Util::Log;
use Flair::Util::LoadHashFile;
use Data::Dumper::Concise;
use Log::Log4perl::Level;
use Try::Tiny;
use feature 'say';

log_init('stdout.conf');
my $log = get_logger('Flair');
$log->level($TRACE);

$log->trace("Starting $0");

my $config      = build_config();
my $sqlconfig   = $config->{database};
my $myconfig    = $config->{newdb};
my $regex_file_dir = $config->{regex_set_dir};

if (migrated_to_mysql()) {
    $log->info("Migration to Mysql has already happened.");
}
else {

    migrate_to_mysql();
}

my $db       = Flair::Db->new(
    log     => $log,
    config  => $config->{newdb}
);

if (migrated_to_updated_regex()) {
    $log->info("Migration of all regexes to db appears to have happened already");
}
else {
    migrate_to_updated_regex();
}

sub migrated_to_mysql {
    my $olddb   = $config->{install}->{dbfile}; # same as  $ENV{S4FLAIR_DB_FILE};
    $log->debug("olddb is $olddb");

    if (-e $olddb) {
        $log->debug("that file exists");
        return undef;
    }

    # if flair.db does not exist it was removed or renamed to flair.db.migrated
    # and implies that migration has happened already
    $log->debug("file does not exist, implies no migration necessary");
    return 1;
}

sub migrated_to_updated_regex {
    my $db       = Flair::Db->new(
        log     => $log,
        config  => $config->{newdb}
    );
    # look for core regex in new regex table created by db migrations file
    # if any exist, we have previously migrated
    my $list    = $db->regex->list({limit => 2});
    # say Dumper($list->[0]);
    # exit 0;
    if (defined $list->[0]->{re_group}) {
        return 1;
    }
    return undef;
}

sub migrate_to_updated_regex {
    my $db       = Flair::Db->new(
        log     => $log,
        config  => $config->{newdb}
    );

    my $migfile = $config->{newdb}->{migration} // "/opt/flair/etc/flair.mysql.sql";
    $db->dbh->migrations->from_file($migfile)->migrate;

    # then udef Regexes

    my $r   = $db->regex_v1->list({});
    foreach my $re (@$r) {
        my $id      = delete $re->{regex_id};
        $log->debug("Moving RE ".$re->{name}." to new table");
        my $type    = delete $re->{regex_type};
        my $group   = "core";
        if ($type eq "udef") {
            $group = "udef";
            if ($re->{entity_type} eq "supplier") {
                $group = "supplier";
                $re->{re_order} += 2000;
            }
            else {
                $re->{re_order} += 1000;
            }
        }
        $re->{re_group} = $group;
        $re->{re_type}  = $type;
        $db->regex->create($re);
    }
}

sub migrate_to_mysql {
    $log->warn("migrating sqlitedb to mysql");
	my $olddb = $ENV{S4FLAIR_DB_FILE};
	my $migdb = $olddb.'.migrated';

	my $sqldb = Flair::Db->new(
		log     => $log,
		config  => $sqlconfig,
	);
	my $mydb  = Flair::Db->new(
		log     => $log,
		config  => $myconfig,
	);

	$log->warn("Initializing Mysql Database");
	my $migfile = $ENV{S4FLAIR_MYSQLDB_MIGRATION} // "/opt/flair/etc/flair.mysql.sql";
	$mydb->dbh->migrations->from_file($migfile)->migrate(0)->migrate;


	foreach my $table (qw(metrics apikeys admins regex)) {
		$log->info("Migrating $table table...");
		my @rows    = @{ $sqldb->$table->list({}) };
		foreach my $row (@rows) {
			delete $row->{updated};
			try {
				$mydb->$table->create($row);
			} catch {
				print "$table : ".Dumper($row);
				print "$!, skipping...\n\n";
			}
		}
	}

	$log->info("Migration complete, renaming $olddb to $migdb");
	rename $olddb, $migdb;
    
}
