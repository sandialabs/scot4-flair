package Flair::Util::Log;

# functions to set up logging 

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(log_init get_logger);

use strict;
use warnings;
use feature qw(signatures say);
no warnings qw(experimental::signatures);

use Log::Log4perl;
use Data::Dumper;

sub get_logger ($logger="Flair") {
        die "Logger not configured" unless Log::Log4perl->initialized();
        say "Returning Logger $logger";
        return Log::Log4perl->get_logger($logger);
}

sub log_init($config=undef){
    return if Log::Log4perl->initialized();
    
    # 1st, need to know if a simple string or a ref to a string is passed in.
    # a simple string = a filename to look for
    # a ref = string containing the log4perl config

    if (is_string_config($config)) {
        Log::Log4perl->init_once($config);
        return;
    }

    my $fqn = find_config($config);
    say "Found $fqn...";
    if (defined $fqn) {
        Log::Log4perl->init_once($fqn);
        return;
    }
    
    # now we are in error situation, not a config string and log config file not found
    # let's die for now, later we can think about a sane default

    die "Unable to Find Log Config File!";

}

sub is_string_config ($config) {
    return (ref($config) eq "SCALAR" and defined($config));
}

sub is_readable ($file) {
    if ( -r $file ) {
        return $file;
    }
    die "Unable to read log config file $file.";
}

sub find_config ($filename) {

    if ( is_fully_qualified($filename) or is_relative_path($filename) ) {
        return is_readable($filename);
    }

    if ( is_tilde_path($filename) ) {
        my $newname = glob($filename);
        return is_readable($newname);
    }

    my @paths   = (qw(
        .
        ~/flair/etc
        ~/Flair/etc
        /opt/flair/etc
        ./etc
    ));

    foreach my $path (@paths) {
        my $fqn = ( glob(join('/',$path, $filename)) )[0];
        next if ! defined $fqn;
        return $fqn if (-r $fqn);
    }
    # woe is me, no config file
    die "Unable to find log config file $filename in path: ".join(':',@paths);
}

sub is_fully_qualified ($file) {
    return ($file =~ /^\/.+/);
}

sub is_tilde_path ($file) {
    return ($file =~ /^~.+/);
}

sub is_relative_path ($file) {
    return ($file =~ /^\.+\/.+/);
}

1;
