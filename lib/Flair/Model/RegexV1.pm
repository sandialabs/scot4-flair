package Flair::Model::RegexV1;

use lib '../../../lib';
use Flair::Regex;
use Flair::Util::LoadHashFile;
use Data::Dumper::Concise;
use SQL::Abstract::Limit;
use Try::Tiny;
use Storable qw(dclone);
use Mojo::Base 'Flair::Model', -signatures;

has 'tablename' => 'regex_v1';

# only list is needed since we are just using this model to transition to new regex table

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
    # $self->log->trace("list result ",{filter=>\&Dumper, value=>$res});
    return $res;
}

sub create ($self, $href) {
    my $sql     = $self->getSAL;
    my $rehref  = dclone($href);

    delete $rehref->{regroup};

    $rehref->{'`match`'} = delete $rehref->{match};
    my ($stmt, @bind) = $sql->insert($self->tablename, $rehref);
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $id = $self->do_query($stmt, @bind)->last_insert_id;
    return $self->fetch($id);
}

1;
