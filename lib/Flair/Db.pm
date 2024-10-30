package Flair::Db;

use lib '../../lib';
use Flair::Model::Admins;
use Flair::Model::Regex;
use Flair::Model::Metrics;
use Flair::Model::Files;
use Flair::Model::Apikeys;
use Flair::Model::Jobs;
use Mojo::SQLite;
use Mojo::Base -base, -signatures;
use Module::Runtime qw(require_module);

# instantiate to get handles to sqlite database
# and to models for the tables

has 'log';
has 'config';

has dbtype  => sub ($self) {
    return 'sqlite';
};

has dbclass => sub ($self) {
    return "Mojo::SQLite"   if ($self->dbtype =~ /sqlite/i);
    die "Unsupported dbtype : ".$self->dbtype;
};

has minion_backend  => sub ($self) {
    return { SQLite => $self->config->{backend} };
};

has connstr => sub ($self) {
    return $self->config->{uri};
};

has dbh  => sub ($self) {
    my $class   = $self->dbclass;
    return $class->new($self->connstr);
};

has regex => sub ($self) {
    return Flair::Model::Regex->new(
        dbh     => $self->dbh, 
        log     => $self->log, 
        config  => $self->config->{model}->{regex},
        dbtype  => $self->dbtype,
    );
};

has metrics => sub ($self) {
    return Flair::Model::Metrics->new(
        dbh     => $self->dbh, 
        dbtype  => $self->dbtype,
        log     => $self->log, 
        config  => $self->config->{model}->{metrics}
    );
};

has apikeys => sub ($self) {
    return Flair::Model::Apikeys->new(
        dbh     => $self->dbh, 
        dbtype  => $self->dbtype,
        log     => $self->log, 
        config  => $self->config->{model}->{apikeys}
    );
};

has admins => sub ($self) {
    return Flair::Model::Admins->new(
        dbh     => $self->dbh, 
        dbtype  => $self->dbtype,
        log     => $self->log, 
        config  => $self->config->{model}->{admins}
    );
};

has jobs => sub ($self) {
    return Flair::Model::Jobs->new(
        dbh     => $self->dbh, 
        dbtype  => $self->dbtype,
        log     => $self->log, 
        config  => $self->config->{model}->{jobs}
    );
};

sub add_metric ($self, $metric, $value) {
    $self->metrics->add_metric($metric, $value);
}

sub build_flair_regexes ($self, $opts) {
    return $self->regex->build_flair_regexes($opts);
}

1;
