package Flair::Util::Crypt;

# export useful functions regarding crypto

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(
            init_pbkdf
            hash_pass
            compare_pass
          );

use strict;
use warnings;
use feature qw(say signatures);
no warnings qw(experimental::signatures);

use Crypt::PBKDF2;
use Data::Dumper::Concise;

sub init_pbkdf () {
    my $pbkdf   = Crypt::PBKDF2->new(
        hash_class  => 'HMACSHA2',
        hash_args   => { sha_size => 512 },
        iterations  => 10000,
        salt_len    => 15,
    );
    return $pbkdf;
}

sub hash_pass ($string) {
    my $p = init_pbkdf();
    return $p->generate($string);
}

sub compare_pass ($hash, $string) {
    my $p   = init_pbkdf();
    return $p->validate($hash, $string);
}

1;
__END__
=head1 Name

Flair::Util::Crypt

=head1 Description

Package of convenience functions for working with PBKDF2 hashes

=head1 Synopsis

    use Flair::Util::Crypt qw(hash_pass compare_pass);

    my $hashed_password = hash_pass($input);
    my $guess = "foo";
    if ( compare_pass($hashed_password, $guess) ) {
        say "Good guess";
    }

=head1 Author

Todd Bruner (tbruner@sandia.gov)

=cut

