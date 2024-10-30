package Flair::Util::LoadHashFile;

# load a file containing a perl hash into memory

use Mojo::Base -base, -signatures;
use Mojo::File qw(path curfile);
use Mojo::Util qw(decode);
use Data::Dumper::Concise;

sub get_hash ($self, $filename) {
    if (! -e $filename) {
        die "$filename does not exist!";
    }
    return $self->load($filename);
}

sub load ($self, $file) {
    return $self->parse(
        decode('UTF-8', path($file)->slurp), $file
    );
}

sub parse ($self, $content, $file) {
    my $sandbox = qq{
package Mojolicious::Plugin::Config::Sandbox;
no warnings;
use Mojo::Base -strict;
$content
};
    my $hash    = eval $sandbox;
    
    die "Cant load hash from file $file: $@" if $@;
    die "File did not return hash ref" unless ref $hash eq 'HASH';
    return $hash;
}

1;
