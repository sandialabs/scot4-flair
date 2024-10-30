package Flair::Util::Sparkline;

# functions to work with sparklines

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(
            contains_sparkline
            contains_multi_row_sparklines
            normalize_sparkline_string
            normalize_sparkline_array
            normalize_new_sparkline_string
            normalize_sparkline
            data_to_sparkline_svg
          );

use strict;
use warnings;
use feature qw(say signatures);
no warnings qw(experimental::signatures);

use SVG::Sparkline;
use Data::Dumper::Concise;

sub contains_sparkline ($cell) {
    if (ref($cell) eq "ARRAY") {
        my $data = $cell->[0];
        return 1 if ($data =~ /##__SPARKLINE__##/);
        return undef;
    }
    return $cell =~ /##__SPARKLINE__##/;
}

sub normalize_sparkline ($cell) {
    # ##__SPARKLINE__##\n0\n1\n2\n0
    # this form of split will split on all whitespace
    my @norm    = split(' ', $cell);
    shift @norm; # remove the __SPARKLINE__
    return @norm;
}

sub normalize_sparkline_array ($cell) {
    shift @$cell;
    my @norm = grep { /\S+/ } @$cell;
    return @norm;
}

sub data_to_sparkline_svg ($cell) {
    my @normalized  = (ref($cell) eq "ARRAY") ? normalize_sparkline_array($cell)
                                              : normalize_sparkline($cell);
    my $svg         = SVG::Sparkline->new(
        Line    => {
            values  => \@normalized,
            color   => 'blue',
            height  => 12,
        }
    );
    return $svg->to_string;
}

sub contains_multi_row_sparklines ($cell) {
    if (ref($cell) eq "ARRAY") {
        my $data    = $cell->[0];
        return 1 if ($data =~ /MULTILINE_SPARKLINE_TABLE/);
        return undef;
    }
    if ($cell =~ /MULTILINE_SPARKLINE_TABLE/) {
        return 1;
    }
    return undef;
}



1;
__END__
=head1 Name

Flair::Util::Sparkline

=head1 Description

Package of convenience functions for working with Sparklines

=head1 Synopsis


=head1 Author

Todd Bruner (tbruner@sandia.gov)

=cut

