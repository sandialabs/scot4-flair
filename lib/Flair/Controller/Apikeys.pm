package Flair::Controller::Apikeys;

use lib '../../../lib';
use strict;
use warnings;
use Data::Dumper::Concise;
use Data::GUID;
use Try::Tiny;
use Mojo::Base 'Flair::Controller::Api', -signatures;
use Carp;

sub default_sort {
    return { -desc => 'apikey_id' };
}

sub create ($self) {

    $self->log->debug("in controller create");

    my $db = $self->db;

    # validate input, return error if not valid
    $self->openapi->valid_input or return $self->invalid_input;

    my $json    = $self->req->json;
    if (! defined $json->{apikey}) {
        # generate an apikey
        my $guid    = Data::GUID->new;
        my $apikey  = $guid->as_string;
        $json->{apikey} = $apikey;
    }

    $self->log->debug({filter=>\&Dumper, value => $json});

    my $href = $self->db->apikeys->create($json);

    # set status and allow openapi to validate output
    $self->render(
        status => 201, 
        openapi => $href
    );
}

sub list ($self) {

    # validate input, return error if not valid
    $self->openapi->valid_input or return;

    my $result = $self->get_list();
    
    $self->render(
        status  => 200,
        openapi => $result,
    );
}

sub get_list ($self) {
    my $json    = $self->req->json;
    my $params  = $self->req->params->to_hash;
    my $opts    = $self->build_list_opts($params);

    return $self->db->apikeys->list($opts);
}

sub fetch ($self) {
    # validate input, return error if not valid
    $self->openapi->valid_input or return;
    my $result  = $self->get_one(); 
    $self->render(
        status  => 200,
        openapi => $result,
    );
}

sub get_one ($self) {
    my $json = $self->req->json;
    my $id   = $self->stash('ApikeyId');
    return $self->db->apikeys->fetch($id);
}

sub update ($self) {

    # validate input, return error if not valid
    $self->openapi->valid_input or return;
    
    my $json = $self->req->json;
    my $id   = $self->stash('ApikeyId');

    my $result  = try {
        $self->db->apikeys->update($id, $json);
    }
    catch {
        die "ERROR: $_";
    };

    $self->render(
        status  => 200,
        openapi => $result,
    );

}

sub patch ($self) {

    # validate input, return error if not valid
    $self->openapi->valid_input or return;
    
    my $json = $self->req->json;
    my $id   = $self->stash('ApikeyId');

    my $result  = try {
        $self->db->apikeys->patch($id, $json);
    }
    catch {
        die "ERROR: $_";
    };
    $self->render(
        status  => 200,
        openapi => $result,
    );
}

sub delete ($self) {
    # validate input, return error if not valid
    $self->openapi->valid_input or return;
    
    my $json = $self->req->json;
    my $id   = $self->stash('ApikeyId');

    my $result  = try {
        $self->db->apikeys->delete($id);
    }
    catch {
        die "ERROR: $_";
    };

    $self->render(
        status  => 200,
        openapi => $result,
    );
}

sub count ($self) {
    $self->openapi->valid_input or return;
    
    my $json = $self->req->json;
    my $result  = try {
        $self->db->apikeys->count($json);
    }
    catch {
        die "ERROR: $_";
    };

    $self->render(
        status  => 200,
        openapi => $result,
    );
}

sub display ($self) {
    return $self->render(result => $self->get_list);
}

sub edit ($self) {
    return $self->render(result => $self->get_one);
}

sub newitem ($self) {
    return $self->render();
}

sub dt ($self) {
    $self->log->debug("dt for apikeys");
    return $self->render();
}

sub dt_ajax ($self) {
    $self->log->debug("dt_ajax for apikeys");
    my $id_formatter   = sub ($value, $column) {
        return '<a href="/flair-ui/flair/edit/apikeys/'.$value.'">'.$value.'</a>';
    };
    my $bool_formatter = sub ($value, $columns) {
        return ($value) ? 'Allowed'  : 'Disallowed';
    };
    my $db  = $self->db->dbh;
    my $ssp = $self->datatable->ssp(
        table   => 'apikeys',
        sql     => $db,
        columns => [
            qw(apikey_id updated username apikey lastaccess flairjob regex_ro regex_crud metrics)
        ],
        options => [
            { label => 'ApikeyId',   db => 'apikey_id', dt => 0, formatter => $id_formatter },
            { label => 'Updated',    db => 'updated',   dt => 1 },
            { label => 'Username',   db => 'username',  dt => 2 },
            { label => 'Apikey',     db => 'apikey',    dt => 3 },
            { label => 'LastAccess', db => 'lastaccess', dt => 4 },
            { label => 'flairjob',   db => 'flairjob', dt => 5, formatter => $bool_formatter },
            { label => 'regex_ro',   db => 'regex_ro', dt => 6, formatter => $bool_formatter },
            { label => 'regex_crud', db => 'regex_crud', dt => 7, formatter => $bool_formatter },
            { label => 'metrics',    db => 'metrics',    dt => 8, formatter => $bool_formatter },
        ],
    );
    return $self->render(json => $ssp);
}


1;
