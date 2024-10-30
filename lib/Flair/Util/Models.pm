package Flair::Util::Models;

# load models into memory

use lib '../../../lib';
use Mojo::Pg;
use Flair::Model::Regex;
use Flair::Model::Metrics;
use Flair::Model::Files;
use Flair::Model::Apikeys;

use Mojo::Base -base, -signatures;

has 'log';
has 'config';

has connstr => sub ($self) {
    return $self->config->{pguri};
};

has pg  => sub ($self) {
   return Mojo::Pg->new($self->connstr); 
};

has regex => sub ($self) {
    return Flair::Model::Regex->new(
        pg => $self->pg, log => $self->log, config => $self->config->{model}->{regex}
    );
};

has metrics => sub ($self) {
    return Flair::Model::Metrics->new(
        pg => $self->pg, log => $self->log, config => $self->config->{model}->{metrics}
    );
};

has files => sub ($self) {
    return Flair::Model::Files->new(
        pg => $self->pg, log => $self->log, config => $self->config->{model}->{files}
    );
};

has apikeys => sub ($self) {
    return Flair::Model::Apikeys->new(
        pg => $self->pg, log => $self->log, config => $self->config->{model}->{apikeys}
    );
};

has admins => sub ($self) {
    return Flair::Model::Admins->new(
        pg => $self->pg, log => $self->log, config => $self->config->{model}->{admins}
    );
};
1;

