package Flair::Model;

use strict;
use warnings;

use SQL::Abstract::Limit;
use Data::Dumper::Concise;
use Try::Tiny;
use Mojo::Base -base, -signatures;

# base (parent) object for models in Models directory

has 'dbh';      # Mojo::SQLite instance
has 'dbtype';   # sqlite
has 'log';      # MojoX::Log::Log4perl instance
has 'config';   # Model defaults

sub extract_kv ($self, $href) {
    my (@keys, @values);

    while (my($k,$v) = each %$href) {
        push @keys, $k,
        push @values, $v;
    }
    return \@keys, \@values;
}

sub do_query ($self, $sql, @bind) {
    my $result  = try {
        my $tx  = $self->dbh->db->begin;
        my $res = $self->dbh->db->query($sql, @bind);
        $tx->commit;
        return $res;
    }
    catch {
        $self->log->error("DB Error: $_");
        return undef;
    };
    return $result;
}

sub getSAL ($self) {
    if ($self->dbtype eq "mysql") {
        return SQL::Abstract::Limit->new(limit_dialect => 'LimitXY');
    }
    return SQL::Abstract::Limit->new(limit_dialect => 'LimitOffset');
}

sub merge_options ($self, $opts, $default) {
    return $default unless defined $opts;
    my $merged  = {};

    foreach my $key (keys %$default) {
        $merged->{$key} = (defined $opts->{$key}) ? $opts->{$key}
                                                  : $default->{$key};
    }
    return $merged;
}

sub log_sql ($self, $model, $sql, @bind) {

    my $msg = join(
        "\n", 
        '-'x20,
        ref($self->dbh),
        "    SQL GENERATED in $model", 
        "    ".$sql,
        "    BindVars: ".join(', ', @bind),
        '-'x78
    );
    
    $self->log->trace($msg);
}

sub log_result ($self, $result) {
    my $msg = join(
        "\n",
        "-"x20,
        ref($result),
        Dumper($result),
        "-"x78
    );
    $self->log->trace($msg);
}

1;
__END__

=head1 Name

Flair::Model - base class for Flair Models

=head1 Attributes

=over 4

=item I<dbh>

The Mojo::x database wrapper instance created in Flair.pm

=item I<log>

The MojoX::Log::Log4perl instance created in Flair.pm

=back

=head1 Methods

=over 4

=item B<extract_kv($self, $href)>

Given a hash reference, this method returns two array references.  The first
a list of the hash keys, and the second contains the corresponding values.

    my ($keys, $values) = $model->extract_kv({ foo => "bar", boom => "baz" });
    say join(',',@$keys);   # foo, boom
    say join(',',@$values); # bar, baz

=item B<do_query($self, $sql, @bind)>

Start a transaction, execute $sql query using @bind values.  Returns Result object

=item B<getSAL($self)>

return an instance of a SQL::Abstract::Limit object with dialect for Postgresql

=item B<merge_options($self, $opts, $default)>

Create a hash reference where the missing items of $opts are filled in with
the values in $default.


    my $default = { one => 1, two => 2, three => 3 };
    my $opts    = { one => 2, three => 6 };
    my $merge   = $self->merge_options($opts, $default);
    say Dumper($merge);
    # { 
    #   one => 2,
    #   two => 2,
    #   three => 6,
    # }

=back

