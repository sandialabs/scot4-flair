package Flair::Model::Metrics;

use lib '../../../lib';
use DateTime;
use Data::Dumper::Concise;
use SQL::Abstract::Limit;
use Try::Tiny;
use Statistics::Descriptive;
use Storable qw(dclone);
use Mojo::Base 'Flair::Model', -signatures;

has 'tablename' => 'metrics';

sub get_metric ($self, $where) {

    my $sql     = $self->getSAL;
    my $cols    = [ qw(metric_id year month day hour metric value)];
    my ($stmt, @bind)   = $sql->select($self->tablename, $cols, $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $collection = $result->hashes;
    my $res        = $collection->to_array;
    $self->log->trace("list result ",{filter=>\&Dumper, value=>$res});
    return $res;
}

sub get_hourly_metrics ($self) {
    my $dt  = DateTime->now;
    my $where   = {
        year    => $dt->year,
        month   => $dt->month,
        day     => $dt->day,
    };
    my %stats   = ();
    my $results = $self->get_metric($where);
    foreach my $row (@$results) {
        my $date_key = join('-', $row->{year}, $row->{month}, $row->{day})." ".$row->{hour};
        my $metric  = $row->{metric};
        push @{$stats{$metric}{label}}, $date_key;
        push @{$stats{$metric}{label}}, $row->{value};
    }
    return wantarray ? %stats : \%stats;
}

sub add_metric ($self, $metric, $value, $dt=undef) {
    $self->log->debug("adding metric $metric $value");
    return $self->add_metric_pg($metric, $value, $dt) if ($self->dbtype eq "pg");
    return $self->add_metric_mysql($metric, $value, $dt) if ($self->dbtype eq "mysql");
    return $self->add_metric_sqlite($metric, $value, $dt);
}

sub get_date_params ($self, $dt=undef) {
    $dt = DateTime->now() if not defined $dt;
    return $dt->year, $dt->month, $dt->day, $dt->hour;
}

sub add_metric_pg ($self, $metric, $value, $dt=undef) {
    my ($y, $m, $d, $h) = $self->get_date_params($dt);
    my $sql = 'SELECT add_metric(?,  ?,  ?,  ?,  ?,       ?)'; 
    my @bind =                  ($y, $m, $d, $h, $metric, $value);
    $self->log_sql(__PACKAGE__, $sql, @bind);
    my $result  = $self->do_query($sql, @bind);
    return $result;
}

sub add_metric_mysql ($self, $metric, $value, $dt=undef) {
    # cant figure out how to write this as a function or otherwise in mysql's poor sql
    my ($y, $m, $d, $h) = $self->get_date_params($dt);
    my $where   = { year => $y, month => $m, day => $d, hour => $h, metric => $metric };
    my $mrecs   = $self->get_metric($where);
    my $mrec    = $mrecs->[0];
    if ( ! defined $mrec ) {
        $where->{value} = $value;
        return $self->create($where);
    }
    my $newval = $mrec->{value} + $value;
    return $self->patch($mrec->{metric_id}, {value =>$newval});
}

sub add_metric_sqlite ($self, $metric, $value, $dt=undef) {
    # cant figure out how to write this as a function or otherwise in mysql's poor sql
    my ($y, $m, $d, $h) = $self->get_date_params($dt);
    my $where   = { year => $y, month => $m, day => $d, hour => $h, metric => $metric };
    my $mrecs   = $self->get_metric($where);
    my $mrec    = $mrecs->[0];
    if ( ! defined $mrec ) {
        $where->{value} = $value;
        return $self->create($where);
    }
    my $newval = $mrec->{value} + $value;
    return $self->patch($mrec->{metric_id}, {value =>$newval});
}

sub get_stats ($self, $where) {
    my $rows    = $self->get_metric($where);
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
    return $self->create_pg($href) if ($self->dbtype eq "pg");
    return $self->create_mysql($href) if ($self->dbtype eq "mysql");
    return $self->create_sqlite($href);
}

sub create_pg ($self, $href) {
    my $sql = $self->getSAL;
    my ($stmt, @bind) = $sql->insert($self->tablename,
                                     $href,
                                     { returning => 'metric_id' });
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $id      = $result->hash->{metric_id};
    return $self->fetch($id);
}

sub create_mysql ($self, $href) {
    my $sql = $self->getSAL;
    my ($stmt, @bind) = $sql->insert($self->tablename,
                                     $href);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind)->last_insert_id;
    return $self->fetch($result);
}

sub create_sqlite ($self, $href) {
    my $sql = $self->getSAL;
    my ($stmt, @bind) = $sql->insert($self->tablename,
                                     $href);
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

sub fetch ($self, $id) {
    my $sql     = $self->getSAL;
    my ($stmt,
        @bind)  = $sql->select($self->tablename,
                                ['*'],
                                { metric_id => $id },
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
    return $self->update_pg($id, $update_href) if ($self->dbtype eq "pg");
    return $self->update_mysql($id, $update_href) if ($self->dbtype eq "mysql");
    return $self->update_sqlite($id, $update_href);
}

sub update_pg ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { metric_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $update_href,
                                     $where,
                                     { returning => 'metric_id' });
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $newid   = $result->hash->{metric_id};
    return $self->fetch($newid);
}

sub update_mysql ($self, $id, $update_href) {
    $self->log->debug("attempting update: ", {filter=>\&Dumper, value=>$update_href});
    my $sql           = $self->getSAL;
    $self->log->debug("after sal");
    my $where         = { metric_id => $id };
    my $href          = dclone($update_href);
    $self->log->debug("after clone");
    delete $href->{metric_id};
    $self->log->debug("attempting update: ", {filter=>\&Dumper, value=>$href});
    my ($stmt, @bind) = $sql->update($self->tablename, $href, $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);

}

sub update_sqlite ($self, $id, $update_href) {
    $self->log->debug("attempting update: ", {filter=>\&Dumper, value=>$update_href});
    my $sql           = $self->getSAL;
    $self->log->debug("after sal");
    my $where         = { metric_id => $id };
    my $href          = dclone($update_href);
    $self->log->debug("after clone");
    delete $href->{metric_id};
    $self->log->debug("attempting update: ", {filter=>\&Dumper, value=>$href});
    my ($stmt, @bind) = $sql->update($self->tablename, $href, $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);

}

sub patch ($self, $id, $update_href) {
    return $self->patch_pg($id, $update_href) if ($self->dbtype eq "pg");
    return $self->patch_mysql($id, $update_href) if ($self->dbtype eq "mysql");
    return $self->patch_sqlite($id, $update_href);
}

sub patch_pg ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { metric_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $update_href,
                                     $where,
                                     { returning => 'metric_id' });
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $newid   = $result->hash->{metric_id};
    return $self->fetch($newid);
}

sub patch_mysql ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { metric_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $update_href,
                                     $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);
}

sub patch_sqlite ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { metric_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $update_href,
                                     $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);
}

sub delete ($self, $id) {
    $self->log->debug("delete $id");
    my $orig          = $self->fetch($id);
    my $sql           = $self->getSAL;
    my $where         = { metric_id => $id };
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
