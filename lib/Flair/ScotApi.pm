package Flair::ScotApi;

use lib '../../lib';
use Data::Dumper::Concise;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Base -base, -signatures;
use MIME::Base64;
use Try::Tiny::Retry ':all';

has 'log';
has 'config';

# create the auth header
has auth_header => sub ($self) {
    if (defined $self->config->{api_key}) {
        return "apikey ".$self->config->{api_key};
    }
    chomp(
        my $enc = encode_base64(join(':', $self->config->{user}, $self->config->{pass}))
    );
    return "basic $enc";
};

# create the user agent
has ua  => sub ($self) {
    my $ua  = Mojo::UserAgent->new();
    $ua->connect_timeout(30);
    $ua->inactivity_timeout(30);
    $ua->proxy->detect;
    $ua->on(start => sub ($ua, $tx) {
        $tx->req->headers->header(
            Authorization => $self->auth_header
        )
    });
    return $ua;
};

sub fetch ($self, $type, $id) {
    my $uri = $self->build_uri_from_msg($type, $id);
    return $self->get($uri);
}
    
sub build_uri_from_msg ($self, $type, $id) {
    return join('/', $self->config->{uri_root},
                     $type,
                     $id);
}

sub get ($self, $uri) {
    my $tx  = $self->ua->insecure($self->config->{insecure})->get($uri);
    my $res = $tx->result;
    my $code = $res->code;

    if ($code != 200) {
        $self->log->error("Error GET $uri. Code = $code");
        die $code;
    }
    return decode_json($res->body);
}

sub post ($self, $uri, $post_data) {
    my $tx  = $self->ua->insecure($self->config->{insecure})->post(
        $uri => {Accept => '*/*'} => json => $post_data
    );

    my $res = $tx->result;
    my $code= $res->code;

    if ( $code != 200 and $code != 202 ) {
        $self->log->error("Error POST $uri. Code = $code");
        die $code." ".$uri;
    }
    return $res;
}

sub put ($self, $uri, $put_data) {
    my $tx = $self->ua->insecure($self->config->{insecure})->put(
        $uri => {Accept => '*/*'} => json => $put_data
    );
    my $res  = $tx->result;
    my $code = $res->code;
    if ( $code != 200 and $code != 202 ) {
        $self->log->error("Error PUT $uri. Code = $code");
        die $code;
    }
    return $res->body;
}

sub patch ($self, $uri, $put_data) {
    my $tx = $self->ua->insecure($self->config->{insecure})->patch(
        $uri => {Accept => '*/*'} => json => $put_data
    );
    my $res  = $tx->result;
    my $code = $res->code;
    if ( $code != 200 and $code != 202 ) {
        $self->log->error("Error PATCH $uri. Code = $code");
        die $code;
    }

    return $res->body;
}

sub delete ($self, $uri) {
    my $tx   = $self->ua->insecure($self->config->{insecure})->delete($uri);
    my $res  = $tx->result;
    my $code = $res->code;
    if ( $code != 200 and $code != 202 ) {
        $self->log->error("Error PATCH $uri. Code = $code");
        die $code;
    }
    return $res->body;
}

sub flair_update_scot4 ($self, $data) {
    my $uri = $self->config->{uri_root}."/flair/flairupdate";

    $self->log->debug("----> Posting to $uri data => ",{filter=>\&Dumper, value=>$data});

    return retry     { $self->post($uri, $data); }
           on_retry  { $self->log->warn("Exception caught, retrying flair update. $_"); }
           delay_exp { 4, 5e6 }
           catch     { 
               $self->log->logdie("Failed to update flair! $_"); 
               return { error => "failed to update scot with flair" };
           };
}

sub upload_file_scot4 ($self, $filename) {
    my $uri = $self->config->{uri_root}."/file/";
    my $data= { file => { file => $filename } };
    my $tx  = $self->ua->insecure($self->config->{insecure})->post(
        $uri => form => $data
    );
    my $res  = $tx->result;
    my $code = $res->code;
    if ($code != 200) {
        $self->log->error("Error ($code) Uploading $filename");
        return { error => "failed to upload $filename to $uri" };
    }
    my $id = $res->json->{id};
    return $id;
} 


1;
