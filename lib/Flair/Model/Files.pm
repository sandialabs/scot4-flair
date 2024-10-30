package Flair::Model::Files;

use lib '../../../lib';
use DateTime;
use Data::Dumper::Concise;
use SQL::Abstract::Limit;
use Try::Tiny;
use Statistics::Descriptive;
use Mojo::Base 'Flair::Model', -signatures;

has 'tablename' => 'files';

sub list ($self, $opts) {
    my $sql             = $self->getSAL;
    my ($stmt, @bind)   = $sql->select($self->tablename,
                                        $opts->{fields},
                                        $opts->{where},
                                        $opts->{order},
                                        $opts->{offset},
                                        $opts->{limit},
                                       );

    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    return undef if not defined $result;
    my $collection = $result->hashes;
    my $res        = $collection->to_array;
    $self->log->trace("list result ",{filter=>\&Dumper, value=>$res});
    return $res;

}

sub fetch ($self, $id) {

    my $sql     = $self->getSAL;
    my $cols    = [qw(*)];
    my $where   = { file_id => $id };
    my ($stmt, @bind)   = $sql->select($self->tablename, $cols, $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $hash    = $result->hash;
    $self->log->trace("fetch result ",{filter=>\&Dumper, value=>$hash});
    return $hash;
}

sub create ($self, $file_href) {
    my $sql             = $self->getSAL;
    my ($stmt, @bind)   = $sql->insert($self->tablename, 
                                       $file_href,
                                       { returning => 'file_id' });
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    my $id      = $result->hash->{file_id};
    return $self->fetch($id);
}

sub update ($self, $id, $update_href) {
    my $sql     = $self->getSAL;
    my $where   = { file_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $update_href,
                                     $where,
                                     { returning => 'file_id' });
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    my $newid   = $result->hash->{file_id};
    return $self->fetch($newid);
}

sub patch ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { file_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $update_href,
                                     $where,
                                     { returning => 'file_id' });
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $newid   = $result->hash->{file_id};
    return $self->fetch($newid);

}

sub delete ($self, $id) {
    my $orig    = $self->fetch($id);
    my $sql     = $self->getSAL;
    my $where   = { file_id => $id };

    my ($stmt, @bind) = $sql->delete($self->tablename, $where);

    $self->log_sql(__PACKAGE__, $stmt, @bind);
    
    my $result  = $self->do_query($stmt, @bind);
    return $orig;
}

sub upsert ($self, $href) {
    my $results = $self->list({
        fields  => [ 'file_id' ],
        where   => { filename => $href->{filename} },
    });
    if (defined $results and scalar @$results > 0 ) {
        return $self->update($results->[0]->{file_id}, $href);
    }
    return $self->create($href);
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
