package Flair::Model::Apikeys;

use lib '../../../lib';
use DateTime;
use Data::Dumper::Concise;
use SQL::Abstract::Limit;
use Try::Tiny;
use Statistics::Descriptive;
use Storable qw(dclone);
use Mojo::Base 'Flair::Model', -signatures;

has 'tablename' => 'apikeys';

sub create ($self, $apikey_href) {
    $self->log->debug("Creating APIKEY");
    return $self->create_sqlite($apikey_href);
}

sub create_sqlite ($self, $apikey_href) {
    my $sql     = $self->getSAL;
    my $href    = dclone($apikey_href);
    my ($stmt, @bind) = $sql->insert($self->tablename,
                                     $href);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $id  = $self->do_query($stmt, @bind)->last_insert_id;
    return $self->fetch($id);
}

sub list ($self, $opts) {
    my $sql     = $self->getSAL;
    my ($stmt,
        @bind)  = $sql->select($self->tablename,
                               $opts->{fields},
                               $opts->{where},
                               $opts->{order},
                               $opts->{offset},
                               $opts->{limit},
                              );
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    return undef if not defined $result;

    my $collection  = $result->hashes;
    my $res         = $collection->to_array;
    $self->log->debug("res = ",{filter => \&Dumper, value => $res});
    return $res;
}

sub fetch ($self, $id) {
    my $sql     = $self->getSAL;
    my ($stmt,
        @bind)  = $sql->select($self->tablename,
                                ['*'],
                                { apikey_id => $id },
                               );
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    return undef if not defined $result;
    return $result->hash;
}

sub update ($self, $id, $update_href) {
    $self->log->debug("performing update");
    return $self->update_sqlite($id, $update_href);
}

sub update_sqlite ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { apikey_id => $id };
    my $href          = dclone($update_href);
    $href->{'`apikey`'}  = delete $href->{apikey};
    my ($stmt, @bind) = $sql->update($self->tablename, $href, $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);
}

sub patch ($self, $id, $update_href) {
    return $self->patch_sqlite($id, $update_href);
}

sub patch_sqlite ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { apikey_id => $id };
    my $href          = dclone($update_href);
    $href->{'`apikey`'}  = delete $href->{apikey};
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $href,
                                     $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);
}

sub delete ($self, $id) {
    $self->log->debug("delete $id");
    my $orig          = $self->fetch($id);
    my $sql           = $self->getSAL;
    my $where         = { apikey_id => $id };
    my ($stmt, @bind) = $sql->delete($self->tablename,
                                     $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    return $orig;
}

sub count ($self, $where) {
    my $sql             = $self->getSAL;
    my ($stmt, @bind)   = $sql->select($self->tablename,
                                       'COUNT(*) as count',
                                       $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $href    = $result->hash;
    return $href;
}

sub set_lastaccess ($self, $apiuser) {
    my $stmt    = "UPDATE apikeys SET lastaccess = CURRENT_TIMESTAMP ".
                  "WHERE username = ? "; 
    my @bind    = ($apiuser);
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    return $self->get_by_user($apiuser);
}

sub get_key ($self, $key) {
    my $sql = $self->getSAL;
    my $fieldname = 'apikey';
    my ($stmt,
        @bind)  = $sql->select($self->tablename, 
                                ['*'],
                                { $fieldname => $key },
                              );
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    return undef if not defined $result;
    return $result->hash;
}

sub get_by_user ($self, $username) {
    my $sql     = $self->getSAL;
    my ($stmt,
        @bind)  = $sql->select($self->tablename,
                              ['*'],
                              { username => $username },
                              );
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    return undef if not defined $result;
    return $result->hash;
}
        
1;
