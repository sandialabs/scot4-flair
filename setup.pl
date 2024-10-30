#!/opt/perl/bin/perl

use Mojo::Base -strict, -signatures;
use Mojo::SQLite;
use Mojo::File;
use Data::Dumper::Concise;
use JSON;
use Minion;
use Getopt::Long;

use lib './lib';
use Flair::Config qw(build_config);
use Flair::Util::LoadHashFile;
use Flair::Db;
use Flair::Util::Log;
use Flair::Util::Crypt qw(hash_pass);

#if ($> != 0) {
#    die "You must be root.  Try: sudo $0\n";
#}

# use the same config as the app
my $config  = build_config();   # create config and set defaults in ENV vars

my $logdir  = $ENV{'S4FLAIR_LOG_DIR'} // '/opt/flair/var/log';
if ( ! -d $logdir ) {
    system("mkdir -p $logdir");
    system("chmod 0750 $logdir");
}

# note: this is simplistic and should work 99% of the time
# The other things that can go wrong that will not catch:
#    disk full
#    mounted read only
# A better test would be to try and open a test file for writing
# and examining error code.  maybe next time I'll implement

my $vardir  = '/opt/flair/var';
if (! -w $vardir) {
    system("chown 7777:7777 $vardir");
}


# get these from helm environment or use defaults
my $dbfile      = $config->{install}->{dbfile};
my $admin_user  = $config->{install}->{admin_user};
my $admin_pass  = $config->{install}->{admin_pass};
my $admin_gecos = $config->{install}->{admin_gecos};
my $instdir     = $config->{install}->{instdir};
my $flair_user  = $config->{install}->{flair_user};
my $flair_group = $config->{install}->{flair_group};
my $core_regexes = $config->{install}->{core_regexes_file};
my $udef_regexes = $config->{install}->{udef_regexes_file};
my $db_migration = $config->{install}->{db_migration};
my $logfile      = $config->{log}->{config};
my $udefnow;

my $wipedb;
my $clean;

GetOptions(
    'clean'     => \$clean,
    'wipedb'    => \$wipedb,
) or die <<EOF;

    USAGE: $0 [--clean] [--wipedb] [--udef /user/defined/flair/regexes.pl ]

        --clean         Removes install dir prior to install
        --wipedb        Deletes SQLite DB and re-initializes
        --udef file     load regex hash in file of format 

            { 
                regexes => [ 
                    {
                        name => 'regex_name',
                        description => 'longer description of regex',
                        match   => q{\b regex \b},
                        entity_type => 'name of entity',
                        regex_type  => 'udef',
                        re_order    => 101,     # lower orders take precedence in matching
                        multiword   => 0,       # or 1 if match spans word boundaries
                    },
                    ...
                ]
            }

EOF

log_init(\$logfile);
my $log = get_logger('Flair');

die "Invalid Install Dir" if ($instdir eq '/' or $instdir eq ' ' or $instdir eq '');

# this should be handled in docker file
# but in case leaving it here, not expecting much from it
my $ugscript = << "EOF";

if grep --quiet -c $flair_group: /etc/group; then
    echo "$flair_group exists, reusing..."
else    
    groupadd $flair_group
fi

if grep --quiet -c $flair_user: /etc/passwd; then
    echo "$flair_user exists, reusing..."
else
    useradd -c "Flair User" -g $flair_group -d $instdir -M -s /bin/bash $flair_user
fi

EOF
# system($ugscript);

# handled in Dockerfile, I hope
#if (-d $instdir) {
#    if ($clean) {
#        system("rm -rf $instdir");
#        system("mkdir -p $instdir");
#    }
#}
#else {
#    system("mkdir -p $instdir");
#}

# more Dockerfile
my $copyscript = << "EOF";
    tar -exclude-vcs -cf - . | (cd $instdir; tar xvf -)
EOF
# system($copyscript);

if ( ! -e $dbfile ) {
    system("touch $dbfile");
}

my $db  = Flair::Db->new(
    log     => $log,
    config  => {
        uri         => 'file:'.$dbfile,
        model       => {},
        migration   => $db_migration,
    }
);
die "Unable to connect to $dbfile" if (! defined $db);

if ($wipedb) {
    unlink $dbfile || die "Unable to remove $dbfile";
    system("touch $dbfile");
    $db->dbh->migrations->from_file($db_migration)->migrate(0)->migrate;
    $db->apikeys->create({
        username    => 'scotapi',
        apikey      => $config->{flair_api_key},
        flairjob    => 1,
        regex_ro    => 1,
        regex_crud  => 1,
        metrics     => 1,
    });
    upsert_regexes($core_regexes);
    if (-e $udef_regexes) {
        upsert_regexes($udef_regexes);
    }
}

my $minion  = Minion->new(SQLite => $config->{database}->{uri});

my $admin_model = $db->admins;
my $list_opts   = {};
my $admin_href  = $admin_model->get_admin($admin_user, "log");

if (! defined $admin_href) {
    my $record  = {
        pwhash      => hash_pass($admin_pass),
        username    => $admin_user,
        who         => $admin_gecos,
    };
    $db->admins->create($record);
}

sub upsert_regexes ($file) {
    my $regexes = Flair::Util::LoadHashFile->new->get_hash($file);
    foreach my $re (@{ $regexes->{regexes} }) {
        $log->debug("Loading Udef Regex: ".$re->{name});
        $log->debug("                  : ".$re->{description});
        my $href    = $db->regex->upsert_re($re);
        $log->debug("regex_id          : ".$href->{regex_id});
    }
}

