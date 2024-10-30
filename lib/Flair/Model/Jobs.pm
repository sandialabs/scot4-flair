package Flair::Model::Jobs;

use lib '../../../lib';
use DateTime;
use Data::Dumper::Concise;
use SQL::Abstract::Limit;
use Try::Tiny;
use Statistics::Descriptive;
use Mojo::Base 'Flair::Model', -signatures;

has 'tablename' => 'jobs';

sub get_job ($self, $where) {

    my $sql     = $self->getSAL;
    my $cols    = [ qw(job_id year month day hour job value)];
    my ($stmt, @bind)   = $sql->select($self->tablename, $cols, $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $collection = $result->hashes;
    my $res        = $collection->to_array;
    $self->log->trace("list result ",{filter=>\&Dumper, value=>$res});
    return $res;
}

sub add_job ($self, $job, $value, $dt=undef) {
    $dt  = DateTime->now() if not defined $dt;
    my $y   = $dt->year;
    my $m   = $dt->month;
    my $d   = $dt->day;
    my $h   = $dt->hour;

    my $sql = 'SELECT add_job(?,  ?,  ?,  ?,  ?,       ?)'; 
    my @bind =                  ($y, $m, $d, $h, $job, $value);
    $self->log_sql(__PACKAGE__, $sql, @bind);
    my $result  = $self->do_query($sql, @bind);
    return $result;
}

sub get_stats ($self, $where) {
    my $rows    = $self->get_job($where);
    my @data    = map {$_->{value} + 0} @$rows;
    my $stat    = Statistics::Descriptive::Full->new();
    $stat->add_data(@data);

    return {
        count   => $stat->count,
        mean    => $stat->mean,
        sum     => $stat->sum,
        stddev  => $stat->standard_deviation,
        min     => $stat->min,
        max     => $stat->max,
        median  => $stat->median,
    };
}

sub create ($self, $href) {
    return $self->create_pg($href)      if ($self->dbtype eq "pg");
    return $self->create_mysql($href)   if ($self->dbtype eq "mysql");
    return $self->create_sqlite($href);
}

sub create_pg ($self, $href) {
    my $sql = $self->getSAL;
    my ($stmt, @bind) = $sql->insert($self->tablename,
                                     $href,
                                     { returning => 'job_id' });
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $id      = $result->hash->{job_id};
    return $self->fetch($id);
}

sub create_mysql ($self, $href) {
    my $sql = $self->getSAL;
    my ($stmt, @bind) = $sql->insert($self->tablename, $href);
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $id  = $self->do_query($stmt, @bind)->last_insert_id;
    return $self->fetch($id);
}

sub create_sqlite ($self, $href) {
    my $sql = $self->getSAL;
    my ($stmt, @bind) = $sql->insert($self->tablename, $href);
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
    return $res;
}

sub fetch ($self, $id) {
    my $sql     = $self->getSAL;
    my ($stmt,
        @bind)  = $sql->select($self->tablename,
                                ['*'],
                                { job_id => $id },
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

sub update ($self, $id, $update_href) {
    return $self->update_pg($id, $update_href)    if ($self->dbtype eq "pg");
    return $self->update_mysql($id, $update_href) if ($self->dbtype eq "mysql");
    return $self->update_sqlite($id, $update_href);
}

sub update_pg ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { job_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $update_href,
                                     $where,
                                     { returning => 'job_id' });
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $newid   = $result->hash->{job_id};
    return $self->fetch($newid);

}

sub update_mysql ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { job_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename, $update_href, $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);
}

sub update_sqlite ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { job_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename, $update_href, $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);
}

sub patch ($self, $id, $patch_href) {
    return $self->patch_pg($id, $patch_href)    if ($self->dbtype eq "pg");
    return $self->patch_mysql($id, $patch_href) if ($self->dbtype eq "mysql");
    return $self->patch_sqlite($id, $patch_href);
}

sub patch_pg ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { job_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $update_href,
                                     $where,
                                     { returning => 'job_id' });
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $newid   = $result->hash->{job_id};
    return $self->fetch($newid);
}

sub patch_mysql ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { job_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename, $update_href, $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);
}

sub patch_sqlite ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { job_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename, $update_href, $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);
}

sub delete ($self, $id) {
    $self->log->debug("delete $id");
    my $orig          = $self->fetch($id);
    my $sql           = $self->getSAL;
    my $where         = { job_id => $id };
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
