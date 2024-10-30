package Flair::Controller::FlairJob;

use Data::Dumper::Concise;
use lib '../../../lib';
use Mojo::Base 'Flair::Controller::Api', -signatures;
use Flair::Processor;


sub default_sort {
    return { -desc => 'flairjob_id' };
}

sub create ($self) {

    # create a minion flair job and return the job id

    # validate input, return error if not valid
    # $self->openapi->valid_input or return;
    if ( ! $self->openapi->valid_input ) {
        $self->log->error("Input from API is invalid");
        return;
    }
    my $input   = $self->req->json;
    $self->log->trace("create flair job ", { filter => \&Dumper, value =>$input});

    $self->log->debug("creating processor...");
    #$self->minion->add_task("flair_it" => sub ($job, @args) {
    #     $job->app->log->debug("INSIDE FLAIR_IT TASK");
    #    $self->log->debug("inside flair_it task");
    #    my $proc = Flair::Processor->new(log => $self->log, db => $self->db);
    #    $proc->do_flairing($job, @args);
    #});
    my $id  = $self->minion->enqueue('flair_it', [$input]);
    $self->log->debug("Minion Job id = $id enqueued"); 

    # set status and allow openapi to validate output
    $self->render(
        status  => 202, 
        json    => { job_id => $id },
    );
}

sub list ($self) {
    $self->log->debug("listing jobs");
    # TODO: define filters ids=>[], notes=>[], queues=>[], states=>[], etc.
    my $jobs    = $self->minion->jobs();
    my @results = ();
    while (my $job = $jobs->next) {
        push @results, $job;
    }
    # $self->log->debug("Results ", {filter=>\&Dumper, value => \@results});
    $self->render(
        status  => 200,
        json    => \@results,
    );
}

sub fetch ($self) {
    $self->openapi->valid_input or return;
    my $id  = $self->stash('FlairJobId');
    my $job = $self->minion->job($id);
    return $self->reply->not_found unless $job;

    $self->log->debug("job $id results ",{filter=>\&Dumper, value=>$job->info});

    $self->render(
        status  => 200,
        json    => $job->info->{result}
    );
}

1;
