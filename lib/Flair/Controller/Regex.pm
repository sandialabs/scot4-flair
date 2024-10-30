package Flair::Controller::Regex;

use lib '../../../lib';
use strict;
use warnings;
use Data::Dumper::Concise;
use HTML::Entities;
use Try::Tiny;
use Mojo::Base 'Flair::Controller::Api', -signatures;
use Carp qw(longmess);

sub default_sort {
    return { -desc => 'regex_id' };
}

sub create ($self) {
    $self->log->debug("create!");

    # validate input, return error if not valid
    $self->openapi->valid_input or return;
    
    try {
        my $json    = $self->req->json;
        my $match   = $json->{match};
        my $id      = $self->db->regex->regex_exists($match);

        if ( ! $id ) {
            my $href = $self->db->regex->create($json);
            $self->log->debug("href = ",{filter=>\&Dumper, value => $href});

            # set status and allow openapi to validate output
            $self->render(
                status => 201, 
                openapi => $href
            );
        }
        else {
            $self->log->debug("Regex exists: $id");
            $self->render(
                status      => 409,
                json        => {regex_id    => $id},
            );
        }
    }
    catch {
        $self->log->error(longmess);
    };
    return;
}

sub list ($self) {

    # validate input, return error if not valid
    $self->openapi->valid_input or return;
    
    my $result  = $self->get_list();

    $self->render(
        status  => 200,
        openapi => $result,
    );
}

sub get_list ($self) {
    my $json    = $self->req->json;
    my $params  = $self->req->params->to_hash;
    my $opts    = $self->build_list_opts($params);

    return $self->db->regex->list($opts);
}

sub fetch ($self) {
    # validate input, return error if not valid
    $self->openapi->valid_input or return;
    
    my $result = $self->get_one();

    $self->render(
        status  => 200,
        openapi => $result,
    );
}

sub get_one ($self) {
    my $json = $self->req->json;
    my $id   = $self->stash('RegexId');
    $self->log->debug("GET ONE $id");
    return  $self->db->regex->fetch($id);
};

sub update ($self) {

    # validate input, return error if not valid
    $self->openapi->valid_input or return;
    
    my $json = $self->req->json;
    my $id   = $self->stash('RegexId');

    my $result  = try {
        $self->db->regex->update($id, $json);
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
    my $id   = $self->stash('RegexId');

    my $result  = try {
        $self->db->regex->patch($id, $json);
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
    my $id   = $self->stash('RegexId');

    my $result  = try {
        $self->db->regex->delete($id);
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
        $self->db->regex->count($json);
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
    $self->log->debug("edit!");
    return $self->render(result => $self->get_one);
}

sub newregex ($self) {
    $self->log->debug('new!');
    return $self->render();
}

sub dt ($self) {
    $self->log->debug("datatable sux");
    return $self->render();
}

sub dt_ajax ($self) {
    $self->log->debug("dt_ajax called");
    my $db  = $self->db->dbh;
    my $ssp = $self->datatable->ssp(
        table   => 'regex',
        sql     => $db,
        columns => [qw(regex_id name description match entity_type regex_type re_order multiword)],
        debug   => 1,
        options => [
            {
                label   => 'RegexId',
                db      => 'regex_id',
                dt      => 0,
                formatter  => sub ($value, $column) {
                    return '<a href="/flair-ui/flair/edit/regex/'.$value.'">'.$value.'</a>';
                },
            },
            { label   => 'Name',        db      => 'name',          dt      => 1, },
            { label   => 'Description', db      => 'description',   dt      => 2, },
            { 
                label   => 'Regex',       
                db      => 'match',         
                dt      => 3, 
                formatter   => sub ($value, $column) {
                    my $v = $value;
                    encode_entities($v);
                    return '<pre>'.$v.'</pre>';
                },
            },
            { label   => 'EntityType',  db      => 'entity_type',   dt      => 4, },
            { label   => 'RegexType',   db      => 'regex_type',    dt      => 5, },
            { label   => 'RegexOrder',  db      => 're_order',      dt      => 6, },
            { label   => 'multiword',   db      => 'multiword',     dt      => 7, },
        ],
    );
    return $self->render(json => $ssp);
}

1;
