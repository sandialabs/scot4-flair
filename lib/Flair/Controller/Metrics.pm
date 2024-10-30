package Flair::Controller::Metrics;

use lib '../../../lib';
use strict;
use warnings;
use Data::Dumper::Concise;
use Try::Tiny;
use Mojo::Base 'Flair::Controller::Api', -signatures;

sub default_sort {
    return { -desc => 'metric_id' };
}

sub create ($self) {

    # validate input, return error if not valid
    $self->openapi->valid_input or return;
    
    my $json = $self->req->json;
    my $href = $self->db->metrics->create($json);

    # set status and allow openapi to validate output
    $self->render(
        status => 201, 
        openapi => $href
    );
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
    return $self->db->metrics->list($opts);
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
    my $id   = $self->stash('MetricId');
    return $self->db->metrics->fetch($id);
}

sub update ($self) {

    # validate input, return error if not valid
    $self->openapi->valid_input or return;
    
    my $json = $self->req->json;
    my $id   = $self->stash('MetricId');

    my $result  = try {
        $self->db->metrics->update($id, $json);
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
    my $id   = $self->stash('MetricId');

    my $result  = try {
        $self->db->metrics->patch($id, $json);
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
    my $id   = $self->stash('MetricId');

    my $result  = try {
        $self->db->metrics->delete($id);
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
        $self->db->metrics->count($json);
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
    return $self->render();
}

sub dt_ajax ($self) {
    my $id_formatter    = sub ($value, $column) {
        return '<a href="/flair-ui/flair/edit/metrics/'.$value.'">'.$value.'</a>';
    };
    my $db  = $self->db->dbh;
    my $ssp = $self->datatable->ssp(
        table   => 'metrics',
        sql     => $db,
        columns => [qw(metric_id year month day hour metric value)],
        options => [
            {label => 'MetricId', db => 'metric_id', dt => 0, formatter => $id_formatter },
            {label => 'Year',     db => 'year',      dt => 1, },
            {label => 'Month',    db => 'month',     dt => 2, },
            {label => 'Day',      db => 'day',       dt => 3, },
            {label => 'Hour',     db => 'hour',      dt => 4, },
            {label => 'Metric',   db => 'metric',    dt => 5, },
            {label => 'Value',    db => 'value',     dt => 6, },
        ],
    );
    return $self->render(json => $ssp);
}

sub status ($self) {
    $self->render();
}

sub stream_status ($self) {
    my $tx  = $self->render_later->tx;
    $self->inactivity_timeout(300);
    $self->res->headers->content_type('text/event-stream');
    $self->write("event:metrics\ndata:".encode_json($self->get_metrics)."\n\n");

    no warnings;
    my $id  = Mojo::IOLoop->recurring(60 => sub {
        $tx;
        my $json    = encode_json($self->get_metrics);
        $self->write("event:metrics\ndata:$json\n\n");
    });
}

1;
