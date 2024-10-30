package Flair::Controller::Api;

use strict;
use warnings;
use Try::Tiny;
use Data::Dumper::Concise;
use Mojo::JSON qw(decode_json);
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub invalid_input ($self) {
    $self->log->error("INVALID INPUT");
    $self->flash(error => "Invalid Input");
}


sub get_request_params ($self) {

    my $mojo_req    = $self->req;
    my $params      = $mojo_req->params->to_hash;
    my $json        = $mojo_req->json;

    if ( $params ) {
        foreach my $key (keys %$params) {
            my $parsed = try {
                # if this param is encoded json, get it and decode
                decode_json($params->{$key});
            }
            catch {
                # otherwise, keep the value as is
                return $params->{$key};
            };
            $params->{$key} = $parsed;
        }
    }

    my $r = {
        id      => $self->stash('id'),
        user    => $self->session('user'),
        data    => {
            params  => $params,
            json    => $json,
        },
    };
    $self->log->trace("REQUEST =",{filter=>\&Dumper, value => $r});
    return $r;
}

sub build_list_opts ($self, $href) {
    my $opts    = {};

    $opts->{fields} = $self->build_fields($href->{fields});
    $opts->{where}  = $self->build_where($href->{where});
    $opts->{order}  = $self->build_order($href->{order});
    $opts->{limit}  = $self->build_limit($href->{limit});
    $opts->{offset} = $self->build_offset($href->{offset});
    return $opts;
}

sub build_fields ($self, $fields) {
    return $fields if (defined $fields and ref($fields) eq "ARRAY"); 
    return ['*'];
}

sub build_where ($self, $where) {
    return $where if (defined $where and ref($where) eq "HASH");
    return {};
}

sub build_order ($self, $order) {
    return $order if (defined $order and ref($order) eq "ARRAY");
    return $self->default_sort;
}

sub build_limit ($self, $limit) {
    return $limit if (defined $limit);
    return 50;
}

sub build_offset ($self, $offset) {
    return $offset if (defined $offset);
    return 0;
}

1;
