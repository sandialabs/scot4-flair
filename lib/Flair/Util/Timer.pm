package Flair::Util::Timer;

# functions to create timers and format dates

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(get_timer get_english_duration get_ymdhms_time);

use strict;
use warnings;
use feature qw(say signatures);
no warnings qw(experimental::signatures);

use DateTime;
use Time::Duration;
use Time::HiRes qw(gettimeofday tv_interval);
use Data::Dumper::Concise;

sub get_timer ($title='', $log=undef) {

    my $start = [ gettimeofday ];
    my $msg   = $title;

    return sub {
        my $begin   = $start;
        my $elapsed = tv_interval($begin, [ gettimeofday ]);

        if ( defined $log ) {
            my $m = sprintf "TIMER: %-30s => %10f seconds", $msg, $elapsed;
            (ref($log) eq "Log::Log4perl::Logger") ?  $log->info($m) : say $m;
        }
        return $elapsed;
    }
}

sub get_english_duration ($seconds) {
    return duration_exact($seconds);
}

sub get_ymdhms_time ($epoch=undef) {
    my $dt = (defined $epoch) ? DateTime->from_epoch(epoch => $epoch) : DateTime->now();
    return join(" ",$dt->ymd, $dt->hms);
}

1;
__END__
=head1 Name

Flair::Util::Timer

=head1 Description

Package of convenience functions for Time related matters in the Flair engine.

=head1 Synopsis

    use Flair::Util::Timer;

    my $timer = get_timer("Foo Time");
    # do stuff, time passes
    my $elapsed = &$timer; # elapsed is number of secondes between init and call

    my $log = Log::Log4perl->get_logger();
    my $timer = get_timer("Boom timer", $log);
    # do stuff, time passes
    my $elapsed = &$timer;
    # log will contain line like:
    # 2022/03/04 10:03:17   INFO [100998] TIMER: Boom timer => 3.3211345 seconds

=head1 Author

Todd Bruner (tbruner@sandia.gov)

=cut

