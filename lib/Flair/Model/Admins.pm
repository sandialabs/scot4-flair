package Flair::Model::Admins;

use lib '../../../lib';
use DateTime;
use Data::Dumper::Concise;
use SQL::Abstract::Limit;
use Try::Tiny;
use Statistics::Descriptive;
use Mojo::Base 'Flair::Model', -signatures;

has 'tablename' => 'admins';

sub create ($self, $admin_href) {
    if ($self->dbtype eq "pg") {
        return $self->create_pg($admin_href);
    }
    if ($self->dbtype eq "mysql") {
        return $self->create_mysql($admin_href);
    }
    # sqlite
    $self->create_sqlite($admin_href);
}

sub create_pg ($self, $admin_href) {
    my $sql = $self->getSAL;
    my ($stmt, @bind) = $sql->insert($self->tablename,
                                     $admin_href,
                                     { returning => 'admin_id' });
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    $self->log_result($result);
    my $id      = $result->hash->{admin_id};
    return $self->fetch($id);
}

sub create_mysql ($self, $admin_href) {
    my $sql = $self->getSAL;
    my ($stmt, @bind)   =  $sql->insert($self->tablename,
                                        $admin_href);
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind)->last_insert_id;
    return $self->fetch($result);
}

sub create_sqlite ($self, $admin_href) {
    my $sql = $self->getSAL;
    my ($stmt, @bind)   =  $sql->insert($self->tablename,
                                        $admin_href);
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind)->last_insert_id;
    return $self->fetch($result);
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
    return $res;
}

sub get_admin ($self, $username, $logsql=undef) {
    my $sql     = $self->getSAL;
    my ($stmt,
        @bind)  = $sql->select($self->tablename,
                                ['*'],
                                { username => $username },
                               );
    $self->log_sql(__PACKAGE__, $stmt, @bind) if $logsql;

    my $result  = $self->do_query($stmt, @bind);
    return undef if not defined $result;
    return $result->hash;
}


sub fetch ($self, $id) {
    my $sql     = $self->getSAL;
    my ($stmt,
        @bind)  = $sql->select($self->tablename,
                                ['*'],
                                { admin_id => $id },
                               );
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    return undef if not defined $result;
    return $result->hash;
}

sub get_key ($self, $key) {
    my $sql = $self->getSAL;
    my ($stmt,
        @bind)  = $sql->select($self->tablename, 
                                ['*'],
                                { key   => $key },
                              );
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    return undef if not defined $result;
    return $result->hash;
}

sub update  ($self, $id, $update_href) {
    return $self->update_pg($id, $update_href) if ($self->dbtype eq "pg");
    return $self->update_mysql($id, $update_href) if ($self->dbtype eq "mysql");
    $self->update_sqlite($id, $update_href);
}

sub update_pg ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { admin_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $update_href,
                                     $where,
                                     { returning => 'admin_id' });
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $newid   = $result->hash->{admin_id};
    return $self->fetch($newid);

}

sub update_mysql ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { admin_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $update_href,
                                     $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);
}

sub update_sqlite ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { admin_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $update_href,
                                     $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);
}

sub patch ($self, $id, $update_href) {
    if ($self->dbtype eq "pg") {
        return $self->patch_pg($id, $update_href);
    }
    if ($self->dbtype eq "mysql") {
        return $self->patch_mysql($id, $update_href);
    }
    return $self->patch_sqlite($id, $update_href);
}

sub patch_pg ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { admin_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $update_href,
                                     $where,
                                     { returning => 'admin_id' });
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $newid   = $result->hash->{admin_id};
    return $self->fetch($newid);
}

sub patch_mysql ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { admin_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $update_href,
                                     $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);
}

sub patch_sqlite ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { admin_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $update_href,
                                     $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);
}

sub set_lastlogin ($self, $username) {
    my $stmt    = "UPDATE admins SET lastlogin = CURRENT_TIMESTAMP WHERE username = ? "; 
    $stmt .= " RETURNING admin_id" if ($self->dbtype eq 'pg');
    my @bind    = ($username);
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    if ( $self->dbtype eq "pg" ) {
        my $id      = $result->hash->{admin_id};
        my $updated = $self->fetch($id);
        return $updated;
    }
    # mysql for more fun!
    return $self->get_admin($username);
}

sub set_lastaccess ($self, $username) {
    return $self->set_lastaccess_pg($username)     if ($self->dbtype eq "pg");
    return $self->set_lastaccess_mysql($username)  if ($self->dbtype eq "mysql");
    return $self->set_lastaccess_sqlite($username);
}

sub set_lastaccess_pg ($self, $username) {
    my $stmt    = "UPDATE admins SET lastaccess = CURRENT_TIMESTAMP WHERE username = ? RETURNING admin_id";
    my @bind    = ($username);
    # $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    my $id      = $result->hash->{admin_id};
    my $updated = $self->fetch($id);
    return $updated;
}

sub set_lastaccess_mysql ($self, $username) {
    my $stmt    = "UPDATE admins SET lastaccess = CURRENT_TIMESTAMP WHERE username = ?";
    my @bind    = ($username);
    # $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    my $updated = $self->get_admin($username);
    return $updated;
}

sub set_lastaccess_sqlite ($self, $username) {
    my $stmt    = "UPDATE admins SET lastaccess = CURRENT_TIMESTAMP WHERE username = ?";
    my @bind    = ($username);
    # $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    my $updated = $self->get_admin($username);
    return $updated;
}

sub delete ($self, $id) {
    $self->log->debug("delete $id");
    my $orig          = $self->fetch($id);
    my $sql           = $self->getSAL;
    my $where         = { admin_id => $id };
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
        
1;
