package Flair::Config;

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(build_config set_default);

use strict;
use warnings;
use experimental 'signatures';
use Data::Dumper::Concise;
use Mojo::File qw(path curfile);
use Mojo::Util qw(decode);

# $ENV is perl special variable to access the shell environment
# flair expects to run in a k3s orchestrated container with helm providing
# the env vars

sub set_default ($varname, $value) {
    # set the environment var to a default value if it doesnt exist
    if (! defined $ENV{$varname}) {
        $ENV{$varname} = $value;
    }
}

# build a config
# based on env vars from helm charts

sub build_config () {
    set_default('S4FLAIR_VERSION',          '1.1');
    # set mode to 'development' to get more descriptive errors in web results
    set_default('S4FLAIR_MODE',             'production');
    # set to INFO or higher to dramatically reduce logging
    set_default('S4FLAIR_LOG_LEVEL',        'DEBUG');
    set_default('S4FLAIR_LOG_DIR',          '/opt/flair/var/log');
    set_default('S4FLAIR_LOG_FILE',         'flair.log');
    set_default('S4FLAIR_MOJO_LISTEN',      'http://localhost:3001?reuse=1');
    set_default('S4FLAIR_MOJO_WORKERS',     5);
    # re-authentication timeout for web app
    set_default('S4FLAIR_DEFAULT_EXP_TIME', 60*60*4);
    # sqlite3 file for storing persistent data
    set_default('S4FLAIR_DB_URI',           'file:/opt/flair/var/flair.db');
    # admin user at start
    set_default('S4FLAIR_ADMIN_USER',       'flairadmin');
    set_default('S4FLAIR_ADMIN_PASS',       'flairrox!');
    set_default('S4FLAIR_ADMIN_GECOS',      'Flair Admin Entity');
    # where flair engine is installed
    set_default('S4FLAIR_HOME_DIR',         '/opt/flair');
    # owner and group of the flair engine files
    set_default('S4FLAIR_FLAIR_USER',       'flair');
    set_default('S4FLAIR_FLAIR_GROUP',      'flair');
    # setup the sqlite db
    set_default('S4FLAIR_DB_MIGRATION',     '/opt/flair/etc/flair.sqlite.sql');
    set_default('S4FLAIR_DB_FILE',          '/opt/flair/var/flair.db');
    # loads the core regexes
    set_default('S4FLAIR_CORE_REGEXES',     '/opt/flair/etc/core_regexes.pl');
    # loads user defined regexes
    set_default('S4FLAIR_UDEF_REGEXES',     '/opt/flair/etc/udef_regexes.pl');
    # if your scot api server is using an expired or invalid cert
    set_default('S4FLAIR_SCOT_API_INSECURE_SSL', 0);
    # the key to submit back to the scot api
    set_default('S4FLAIR_SCOT_API_KEY',     'xxxxxx');
    # uri base 
    set_default('S4FLAIR_SCOT_API_URI_ROOT', 'https://scot4/api/v1');
    set_default('S4FLAIR_SCOT_EXTERNAL_HOSTNAME', 'scot4');
    
    my $logfile = join('/', $ENV{S4FLAIR_LOG_DIR}, $ENV{S4FLAIR_LOG_FILE});

    my $config  = {
        version     => $ENV{S4FLAIR_VERSION},
        mode        => $ENV{S4FLAIR_MODE},
        scot_external_hostname => $ENV{S4FLAIR_SCOT_EXTERNAL_HOSTNAME},
        install     => {
            dbfile      => $ENV{S4FLAIR_DB_FILE},
            admin_user  => $ENV{S4FLAIR_ADMIN_USER},
            admin_pass  => $ENV{S4FLAIR_ADMIN_PASS},
            admin_gecos => $ENV{S4FLAIR_ADMIN_GECOS},
            instdir     => $ENV{S4FLAIR_HOME_DIR},
            flair_user  => $ENV{S4FLAIR_FLAIR_USER},
            flair_group => $ENV{S4FLAIR_FLAIR_GROUP},
            db_migration => $ENV{S4FLAIR_DB_MIGRATION},
            core_regexes_file   => $ENV{S4FLAIR_CORE_REGEXES},
            udef_regexes_file   => $ENV{S4FLAIR_UDEF_REGEXES},
        },
        log         => {
            name    => 'Flair',
            config  => qq{
log4perl.category.Flair = $ENV{S4FLAIR_LOG_LEVEL}, FlairLog
log4perl.appender.FlairLog = Log::Log4perl::Appender::File
log4perl.appender.FlairLog.mode = append 
log4perl.appender.FlairLog.filename = $logfile
log4perl.appender.FlairLog.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.FlairLog.layout.ConversionPattern = %d %5p %15F{1}:%4L %m%n
            },
        },
        hypnotoad   => {
            listen  => [ $ENV{S4FLAIR_MOJO_LISTEN} ],
            workers => $ENV{S4FLAIR_MOJO_WORKERS},
            clients => 1,
            proxy   => 1,
            pidfile => '/opt/flair/var/run/flair.hypno.pid',
            heartbeat_timeout   => 90,
        },
        secrets             => [qw(l1nd@ 5yd3ny m@dd0x br00ke)], 
        default_expiration  => $ENV{S4FLAIR_DEFAULT_EXP_TIME},
        flair_api_key       => $ENV{S4FLAIR_FLAIR_API_KEY},
        database            => {
            dbtype      => 'sqlite',
            uri         => $ENV{S4FLAIR_DB_URI},
            backend     => 'sqlite:'.$ENV{S4FLAIR_DB_FILE},
            migration   => $ENV{S4FLAIR_DB_MIGRATION},
            model       => {
                regex   => {
                    default_list_options => {
                        fields  => ['*'],
                        where   => [],
                        order   => [ '-id' ],
                        limit   => 50,
                        offset  => 0,
                    },
                    default_fetch_options   => {
                        fields  => ['*'],
                        where   => [],
                        order   => [ '-id' ],
                        limit   => 1,
                        offset  => 0,
                    },
                },
            },
        },
        scotapi => {
            insecure => $ENV{S4FLAIR_SCOT_API_INSECURE_SSL}, 
            api_key  => $ENV{S4FLAIR_SCOT_API_KEY}, 
            uri_root => $ENV{S4FLAIR_SCOT_API_URI_ROOT},
        },
        flair_job_test => $ENV{S4FLAIR_JOB_TEST} // undef,
    };
    return $config;
}

1;
