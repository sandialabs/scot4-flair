package Flair::Model::Regex;

use lib '../../../lib';
use Flair::Regex;
use Data::Dumper::Concise;
use SQL::Abstract::Limit;
use Try::Tiny;
use Storable qw(dclone);
use Mojo::Base 'Flair::Model', -signatures;

has 'tablename' => 'regex';

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

sub fetch ($self, $id) {

    $self->log->debug("fetch = $id");
   # my $stmt    = "SELECT * FROM ".$self->tablename." WHERE id = ?";
   # my @bind    = ($id);

    my $sql             = $self->getSAL;
    my ($stmt, @bind) = $sql->select($self->tablename,
                                     ['*'],
                                     { regex_id => $id },
                                    );
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $rhash   = $result->hash;
    return $rhash;
}

sub create ($self, $regex_href) {
    return $self->create_pg($regex_href) if ($self->dbtype eq "pg");
    return $self->create_mysql($regex_href) if ($self->dbtype eq "mysql");
    return $self->create_sqlite($regex_href);
}

sub create_pg ($self, $regex_href) {
    $self->log->debug("REGEX Create");
    $self->log->debug("regex = ", { filter => \&Dumper, value => $regex_href});

    my $href            = dclone($regex_href);

    if ($self->contains_whitespace($href->{match}) and ! $href->{multiword} ) {
        $href->{multiword} = 1;
    }

    my $sql = $self->getSAL;
    my ($stmt, @bind) = $sql->insert($self->tablename,
                                     $href,
                                     { returning => 'regex_id' });
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $id      = $result->hash->{regex_id};
    return $self->fetch($id);
}

sub create_mysql ($self, $regex_href) {
    my $sql             = $self->getSAL;
    my $href            = dclone($regex_href);

    if ($self->contains_whitespace($href->{match}) and ! $href->{multiword} ) {
        $href->{multiword} = 1;
    }

    $href->{'`match`'}  = delete $href->{match};
    my ($stmt, @bind)   = $sql->insert($self->tablename, $href);
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $id  = $self->do_query($stmt, @bind)->last_insert_id;
    return $self->fetch($id);
}

sub create_sqlite ($self, $regex_href) {
    my $sql             = $self->getSAL;
    my $href            = dclone($regex_href);

    if ($self->contains_whitespace($href->{match}) and ! $href->{multiword} ) {
        $href->{multiword} = 1;
    }

    $href->{'`match`'}  = delete $href->{match};
    my ($stmt, @bind)   = $sql->insert($self->tablename, $href);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $q = $self->do_query($stmt, @bind);
    if ( ! defined $q ) {
        die "Error: $_\n stmt = $stmt \nbind = ",Dumper(\@bind);
    }
    my $id = $q->last_insert_id;
    return $self->fetch($id);
}

sub contains_whitespace ($self, $match) {
    return $match =~ /[     ]/;
}

sub escape_spaces ($self, $match) {
    my $escaped = dclone($match);
    $escaped =~ s/ /\\ /g;  # space
    $escaped =~ s/  /\\ /g; # tab
    return $escaped;
}

sub update ($self, $id, $update_href) {
    return $self->update_re($id, $update_href) if ($self->dbtype eq "pg");
    return $self->update_mysql($id, $update_href) if ($self->dbtype eq "mysql");
    return $self->update_sqlite($id, $update_href);
}

sub update_pg ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { regex_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $update_href,
                                     $where,
                                     { returning => 'regex_id' });
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $newid   = $result->hash->{regex_id};
    return $self->fetch($newid);
}

sub update_mysql ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { regex_id => $id };
    my $href          = dclone($update_href);
    $href->{'`match`'} = delete $href->{match};
    my ($stmt, @bind) = $sql->update($self->tablename, $href, $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);
}

sub update_sqlite ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { regex_id => $id };
    my $href          = dclone($update_href);
    $href->{'`match`'} = delete $href->{match};
    my ($stmt, @bind) = $sql->update($self->tablename, $href, $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);
    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);
}

sub patch ($self, $id, $update_href) {
    return $self->patch_pg($id, $update_href)    if ($self->dbtype eq "pg");
    return $self->patch_mysql($id, $update_href) if ($self->dbtype eq "mysql");
    return $self->patch_sqlite($id, $update_href);
}

sub patch_pg ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { regex_id => $id };
    my ($stmt, @bind) = $sql->update($self->tablename,
                                     $update_href,
                                     $where,
                                     { returning => 'regex_id' });
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    my $newid   = $result->hash->{regex_id};
    return $self->fetch($newid);
}

sub patch_mysql ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { regex_id => $id };
    my $href          = dclone($update_href);
    $href->{'`match`'} = delete $href->{match} if (defined $href->{match});
    my ($stmt, @bind) = $sql->update($self->tablename, $href, $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);
}

sub patch_sqlite ($self, $id, $update_href) {
    my $sql           = $self->getSAL;
    my $where         = { regex_id => $id };
    my $href          = dclone($update_href);
    $href->{'`match`'} = delete $href->{match} if (defined $href->{match});
    my ($stmt, @bind) = $sql->update($self->tablename, $href, $where);
    $self->log_sql(__PACKAGE__, $stmt, @bind);

    my $result  = $self->do_query($stmt, @bind);
    return $self->fetch($id);
}


sub delete ($self, $id) {
    $self->log->debug("delete $id");
    my $orig          = $self->fetch($id);
    my $sql           = $self->getSAL;
    my $where         = { regex_id => $id };
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

sub load_core_re ($self) {
    my @re      = ();
    my $core    = Flair::Regex->new();
    my @corere  = $core->core_regex_names;

    foreach my $re_name (@corere) {
        my $href    = $core->$re_name;
        push @re, $href;
    }
    my @sorted  = sort { $a->{re_order} <=> $b->{re_order} } @re;
    return wantarray ? @sorted : \@sorted;

}

sub load_user_def_re ($self, $opts=undef) {
    my @cooked  = ();
    if (not defined $opts) {
        $opts   = {
            fields  => ['*'],
            order   => { -asc => 're_order' },
        };
    }

    my $raw     = $self->list($opts);

    foreach my $href (@$raw) {
        if ( ! defined $href->{regex} or ref($href->{regex}) ne "Rexexp" ) {
            $self->create_re($href);
        }
        push @cooked, $href;
    }
    return wantarray ? @cooked : \@cooked;
}


sub build_flair_regexes ($self, $opts=undef) {
    my @re  = $self->load_core_re();
    push @re, $self->load_user_def_re($opts);
    return wantarray ? @re : \@re;
}

sub create_re ($self, $href) {
    my $match = $href->{match};
    if ($match =~ / / and ! $href->{multiword}) {
        $self->log->warn("Regular Expression $href->{name} contains spaces but was not marked multiword.  Overriding multiword to true.");
        $href->{multiword} = 1;
    }
    die "Must provide match value in RE record." unless defined $match;
    $href->{regex} = ($href->{multiword}) ? qr/($match)/ims 
                                          : qr/\b($match)\b/xims;
}

sub upsert_re ($self, $href) {
    my $results = $self->list({
        fields  => [ 'regex_id' ],
        where   => { 
            name  => $href->{name},
            match => $href->{match},
        },
    });
    $self->log->debug("list result = ",{filter=>\&Dumper, value => $results});

    if (defined $results and scalar @$results > 0) {
        return $self->update($results->[0]->{regex_id}, $href);
    }
    return $self->create($href);
}

sub regex_by_name ($self, $name) {
    my $opts    = {
        fields  => [ '*' ],
        where   => { name => $name },
        order   => { -asc => 're_order' },
    };
    return $self->build_flair_regexes($opts);
}

sub regex_exists ($self, $regex) {
    $self->log->debug("Checking for existing Regex: $regex");
    my $match   = '`match`';
    my $opts    = {
        fields  => [ '*' ],
        where   => { $match => $regex },
    };
    my $regexes = $self->list($opts);
    if (defined $regexes and scalar(@$regexes) > 0) {
        my $existing = $regexes->[0]->{regex_id};
        $self->log->debug("Exists with id = $existing");
        return $existing;
    }
    $self->log->debug("no matching regex");
    return undef;
}

1;
