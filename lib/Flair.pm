package Flair;

use Mojo::Base 'Mojolicious', -signatures;
use Mojo::File qw(curfile);
use MojoX::Log::Log4perl;
use Flair::Util::CSRFProtection;
use Flair::Db;
use Flair::Processor;
use Flair::ScotApi;
use Flair::Config qw(build_config);
use Data::Dumper::Concise;
use Carp qw(cluck longmess shortmess);

##
## This module starts the WEB api
##

sub startup ($self) {

    # Load configuration from config vars
    my $config_href    = build_config();
    $self->plugin('Config' => {default => $config_href});

    # set up logging
    my $logconf = $config_href->{log}->{config};
    $self->log(MojoX::Log::Log4perl->new(\$logconf));
    $self->log->info("Starting Flair Web ...");

    # catch errors and put them in log
    $self->catch_error_setup();

    # Configure the application
    $self->mode($config_href->{mode});
    $self->secrets($config_href->{secrets});
    $self->sessions->default_expiration($config_href->{default_expiration});
    $self->sessions->secure(1);

    # configure plugins
    $self->plugin('TagHelpers');
    $self->plugin('DefaultHelpers');
    $self->plugin('RemoteAddr');
    $self->plugin('Flair::Util::CSRFProtection');


    my $db  = Flair::Db->new(log => $self->log, config => $config_href->{database});
    $self->helper('db'  => sub { $db } );
    $self->attr  ('db' => sub {$db} );
    #
    # Minion admin might be unprotected so add this
    my $minion_auth = $self->routes->under('/minion')->to('controller-auth#check');

    my $mindb = $db->minion_backend;
    $self->plugin('Minion' => $mindb);
    $self->plugin('Minion::Admin' => {route => $minion_auth});
    $self->plugin('Mojolicious::Plugin::DataTables');

    my $cache = Mojo::Cache->new(max_keys => 100);
    $self->helper('cache' => sub { $cache });

    # server settings
    $self->max_request_size($config_href->{max_request_size});
    $| = 1;

    # create a scotapi instance for interaction with the SCOT api
    my $scotapi = Flair::ScotApi->new(log => $self->log, config => $self->config->{scotapi});

    # create flair task
    # (must create here and not in controller)
    $self->minion->add_task("flair_it" => sub ($job, @args) {
        $self->log->debug("Inside flair_it");
        my $processor = Flair::Processor->new(
            log => $self->log, db => $db, scotapi => $scotapi, config => $self->config,
        );
        $processor->do_flairing($job, @args);
    });

    $self->minion->add_task('flair_bulk' => sub ($job, @args) {
        $self->log->debug("Inside flair_bulk");
        my $processor = Flair::Processor->new(
            log => $self->log, db => $db, scotapi => $scotapi, 
            config => $self->config, minion => $self->minion,
        );
        $processor->do_bulk($job, @args);
    });
    
    # this is most likely behind a reverse proxy especiallly in a kubernetes/docker env
    # so set the env var MOJO_REVERSE_PROXY to the path prefeix (likely /scot-flair)
    # see https://mojolicious.io/blog/2019/03/18/reverse-proxy-with-path/

    if ( my $path = $ENV{MOJO_REVERSE_PROXY} ) {
        my @parts = grep /\S/, split m{/}, $path;
        $self->hook(before_dispatch => sub {
            my ($c)     = @_;
            my $url     = $c->req->url;
            my $base    = $url->base;
            push @{ $base->path }, @parts;
            $base->path->trailing_slash(1);
            $url->path->leading_slash(0);
        });
    }
        
    $self->log->debug("Building Routes...");
    # Router
    my $r = $self->routes;


    # authentication routes
    $r->post('/auth')->with_csrf_protection->to('controller-auth#auth')->name('auth');
    $r->any('/login')->to('controller-auth#login')->name('login');
    $r->any('/logout')->to('controller-auth#logout')->name('logout');


    # set up auth handler
    my $auth    = $r->under('/')->to('controller-auth#check');
    # allow static index.html without auth
    $r->get('/')->to(cb => sub ($c) { $c->reply->static('index.html'); });

    $self->plugin('OpenAPI' => { 
        # load the api specification
        url     => $self->home->rel_file('public/api.yaml'),
        # make sure openapi paths are authenticated/authorized
        route   => $auth,
    });

    $self->plugin('SwaggerUI' => {
        route   => $self->routes->any('/swagger'),
        url     => 'api.yaml',
    });

    # make routes with /flair authenticated
    my $flair = $auth->any('/flair');

    $flair->any('/status')       ->to('controller-metrics#status')->name('status');
    $flair->any('/stream_status')->to('controller-metrics#stream_status')->name('stream_status');

    # datatable display routes
    # /flair/dt/*
    my $dt    = $flair->any('/dt');
    $dt->get ('/regex')       ->to('controller-regex#dt')          ->name('regex_dt');
    $dt->get ('/regex/ajax')  ->to('controller-regex#dt_ajax')     ->name('regex_dt_ajax');
    $dt->get ('/apikeys')     ->to('controller-apikeys#dt')        ->name('apikeys_dt');
    $dt->get ('/apikeys/ajax')->to('controller-apikeys#dt_ajax')   ->name('apikeys_dt_ajax');
    $dt->get ('/metrics')     ->to('controller-metrics#dt')        ->name('metrics_dt');
    $dt->get ('/metrics/ajax')->to('controller-metrics#dt_ajax')   ->name('metrics_dt_ajax');
    $dt->get ('/admins')      ->to('controller-admins#dt')         ->name('admins_dt');
    $dt->get ('/admins/ajax') ->to('controller-admins#dt_ajax')    ->name('admins_dt_ajax');

    # editor display routes
    # /flair/edit/*
    my $edit  = $flair->any('/edit');
    $edit->get ('/regex/:RegexId')   ->to('controller-regex#edit')   ->name('regex_edit');
    $edit->get ('/apikeys/:ApikeyId')->to('controller-apikeys#edit') ->name('apikeys_edit');
    $edit->get ('/metrics/:MetricId')->to('controller-metrics#edit') ->name('metrics_edit');
    $edit->get ('/admins/:AdminId')  ->to('controller-admins#edit')  ->name('admins_edit');

    # new item display routes
    # /flair/new/*
    my $new   = $flair->any('/new');
    $new->get ('/regex')   ->to('controller-regex#newregex')  ->name('regex_new');
    $new->get ('/apikeys') ->to('controller-apikeys#newitem') ->name('apikeys_new');
    $new->get ('/metrics') ->to('controller-metrics#newitem') ->name('metrics_new');
    $new->get ('/admins')  ->to('controller-admins#newitem')  ->name('admins_new');


    $self->log_server_startup();
}

sub log_server_startup ($self) {
    my $spaces  = " "x55;
    my $pwd     = `pwd`;
    chomp($pwd);
    my $inc_sep = "\n" . "|       : ";
    my $inc     = join($inc_sep, @INC);

    my @clines  = split("\n",Dumper($self->config));
    my $cfg     = join("\n|         ","|        ", @clines);
    my $message = join("\n","",
        "==========================================================",
        "| SCOT FLAIR Server",
        "| FLAIR : ".$self->config->{version},
        "| Perl  : ".$],
        "| MOJO  : ".$Mojolicious::VERSION,
        "| Mode  : ".$self->mode,
        "| DB    : ".$self->config->{database}->{uri},
        # "| INC   : ".$inc,
        # "| MOJO_REVERSE_PROXY : ".$ENV{MOJO_REVERSE_PROXY},
        "| CONFIG: ", $cfg,
        "==========================================================",
    );
    $self->log->info($message);
}

sub catch_error_setup ($self) {
    $SIG{'__DIE__'} = sub {
        if ( $^S ){
            # in eval, don't log, catch later
            return;
        }
        local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth+1;
        $self->log->error(longmess());
        $self->log->fatal(@_);
        die @_;
    };
    #$SIG{'__WARN__'} = sub {
    #    if ( $^S ){
    #        # in eval, don't log, catch later
    #        return;
    #    }
    #    my $depth = $Log::Log4perl::caller_depth;
    #    $Log::Log4perl::caller_depth++;
    #    $self->log->warn(longmess());
    #    $self->log->warn(@_);
    #    $Log::Log4perl::caller_depth = $depth;
    #};
}
1;
