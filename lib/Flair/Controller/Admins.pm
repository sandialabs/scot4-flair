package Flair::Controller::Admins;

use lib '../../../lib';
use strict;
use warnings;
use Data::Dumper::Concise;
use Crypt::PBKDF2;
use Mojo::Base 'Flair::Controller::Api', -signatures;
use Flair::Util::Crypt qw(hash_pass);

sub default_sort {
    return { -desc => 'admin_id' };
}

sub create ($self) {
    $self->log->debug("Create");
    $self->openapi->valid_input or return $self->invalid_input;
    my $json    = $self->req->json;
    my $raw     = $json->{pwhash};
    $json->{pwhash} = hash_pass($raw);
    my $href    = $self->db->admins->create($json);
    $self->render(status => 201, openapi => $href);
}

sub list ($self) {
    $self->openapi->valid_input or return;
    my $result  = $self->get_list();
    $self->render(status => 200, openapi => $result);
}

sub get_list ($self) {
    my $json    = $self->req->json;
    my $params  = $self->req->params->to_hash;
    my $opts    = $self->build_list_opts($params);
    return $self->db->admins->list($opts);
}

sub fetch ($self) {
    $self->openapi->valid_input or return;
    my $result  = $self->get_one;
    $self->render(status => 200, openapi => $result);
}

sub get_one ($self) {
    my $json    = $self->req->json;
    my $id      = $self->stash('AdminId');
    return $self->db->admins->fetch($id);
}

sub update ($self) {
    $self->openapi->valid_input or return;
    my $json    = $self->req->json;
    my $id      = $self->stash('AdminId');
    my $result  = $self->db->admins->update($id, $json);
    $self->render(status => 200, openapi => $result);
}

sub patch ($self) {
    $self->openapi->valid_input or return;
    my $json    = $self->req->json;
    my $id      = $self->stash('AdminId');
    my $result  = $self->db->admins->patch($id, $json);
    $self->render(status => 200, openapi => $result);
}

sub delete ($self) {
    $self->openapi->valid_input or return;
    my $json    = $self->req->json;
    my $id      = $self->stash('AdminId');
    my $result  = $self->db->admins->delete($id);
    $self->render(status => 200, openapi => $result);
}

sub count ($self) {
    $self->openapi->valid_input or return;
    my $json    = $self->req->json;
    my $result  = $self->db->admins->count($json);
    $self->render(status => 200, openapi => $result);
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
    return $self->render();
}

sub dt_ajax ($self) {
    my $id_formatter    = sub ($value, $column) {
        return '<a href="/flair-ui/flair/edit/admins/'.$value.'">'.$value.'</a>';
    };
    my $db  = $self->db->dbh;
    my $ssp = $self->datatable->ssp(
        table   => 'admins',
        sql     => $db,
        columns => [qw(admin_id updated username who lastlogin lastaccess pwhash)],
        options => [
            {label => 'AdminId',   db => 'admin_id',    dt => 0, formatter => $id_formatter },
            {label => 'Updated',   db => 'updated',     dt => 1, },
            {label => 'Username',  db => 'username',    dt => 2, },
            {label => 'Who',       db => 'who',         dt => 3, },
            {label => 'LastLogin', db => 'lastlogin',   dt => 4, },
            {label => 'LastAccess', db => 'lastaccess', dt => 5, },
            {label => 'PWHash',     db => 'pwhash',     dt => 6, },
        ],
    );
    return $self->render(json => $ssp);
}
1;
