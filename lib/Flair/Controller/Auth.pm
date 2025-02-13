package Flair::Controller::Auth;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Crypt::PBKDF2;
use Data::Dumper::Concise;
use lib '../../../lib';
use Flair::Util::Crypt qw(compare_pass);
use Storable qw(dclone);

sub check ($self) {
    # testing
    # return 1;
    $self->log->debug("Checking Authentication...");
    # look for mojolicious session 
    if ( my $user = $self->valid_mojo_session ) {
        return $self->sucessful_session($user);
    }

    # look for APIKEY
    if ( my $apiuser    = $self->valid_header ) {
        return $self->sucessful_header($apiuser);
    }

    # everything failed, no auth for your
    return $self->failed_auth('invalid session or apikey');
}

sub sucessful_session ($self, $user) {
    $self->db->admins->set_lastaccess($user);
    $self->log_request($user);
    return 1;
}

sub sucessful_header ($self, $apiuser) {
    $self->db->apikeys->set_lastaccess($apiuser);
    $self->log_request($apiuser);
    return 1;
}

sub login ($self) {
    # generate the login form
    $self->render(orig_url => $self->session('orig_url'));
}

sub logout ($self) {
    $self->session(user => '');
    $self->render(
        status      => 200,
        orig_url    => '/',
    );
}

sub auth ($self) {

    my $user    = $self->param('user');
    my $pass    = $self->param('pass');

    $self->log->debug("User $user is attempting to auth");

    # delete leading and trailing spaces from both
    $user   =~ s/^\s+(\w+)\s+$/$1/;
    $pass   =~ s/^\s+(\w+)\s+$/$1/;

    my $admin   = $self->db->admins->get_admin($user);
    return $self->failed_auth("User $user not found") unless $admin;

    if ( $self->hash_match($admin->{pwhash}, $pass) ) {
        return $self->sucessful_auth($user, $self->session('orig_url'));
    }
    $self->failed_auth("$user password mismatch");
}

sub hash_match ($self, $hash, $attempt) {
    return compare_pass($hash, $attempt);
}

sub valid_mojo_session ($self) {
    my $user    = $self->session('user');
    if (defined $user) {
        $self->log->info("User: $user ,  Method: valid session cookie");
        return $user;
    }
    $self->log->info("missing session cookie");
    return undef;
}

sub valid_header ($self) {
    my $headers = $self->req->headers;
    my $header  = $headers->header('authorization');
    $self->log->debug("Authorization header = $header");
    
    unless (defined $header) {
        $self->log->info("No authorization header present");
        return undef;
    }

    my ($type, $value) = split(/ /, $header, 2);
    return $self->validate_header($type, $value);
}

sub validate_header ($self, $type, $value) {
    if ($type eq "basic") {
        if ($self->validate_basic($value)) {
            $self->log->debug("User validated by basic");
            return 1;
        }
    }
    if ($type eq "apikey") {
        if ($self->validate_apikey($value)) {
            $self->log->debug("user validated by authkey");
            return 1;
        }
    }
    return undef;
}

sub validate_basic ($self, $value) {
    my $decoded         = decode_base64($value);
    my ($user, $pass)   = split(/:/, $decoded, 2);
    my $attempted_pass  = $self->generate_pbkdf($pass);
    my $userpwhash      = $self->get_user_pwhash($user);

    if ($self->hash_match($userpwhash, $attempted_pass)) {
        $self->log->info("User: $user Method: basic auth");
        return $user;
    }
    $self->log->debug("Failed basic auth");
    return undef;
}

sub get_user_pwhash ($self, $user) {
    my $record    = $self->db->admins->get_admin($user);
    if ( defined $record ) {
        return $record->{pwhash};
    }
    $self->log->info("User: $user is invalid");
    return undef;
}

sub validate_apikey ($self, $value) {
    my $apikey  = $self->db->apikeys->get_key($value);
    if (defined $apikey) {
        return $apikey->{username};
    }
    $self->log->debug("Failed apikey validation");
    return undef;
}

sub sucessful_auth ($self, $user, $orig_url=undef) {
    $self->log->info("User $user sucessfully authenticated from: ". $self->remote_addr);
    $self->db->admins->set_lastlogin($user);
    $self->session(
        user        => $user,
        secure      => 1,
        expiration  => 3600 * 4, # must re-auth in four hours
    );
    $orig_url = "/" unless $orig_url;
    $self->redirect_to($orig_url);
    return 1;
}

sub failed_auth ($self, $reason) {
    $self->log_request("Failed Auth");
    $self->log->error("Failed Auth Attempt from ".$self->remote_addr.". $reason");
    $self->redirect_to("/login");
    return undef; 
}

sub log_request ($self, $user=undef) {
    my @plines = map { " "x20 . qq|--- |. $_ } split("\n",Dumper($self->req->params->to_hash));
    my $json   = $self->req->json;
    my $json_no_data = (! defined $json or ! ref($json)) ?
        { data => {} } :
        dclone($json);

    delete $json_no_data->{data};
    my @jlines = map { " "x20 . qq|--- |. $_ } split("\n",Dumper($json_no_data));
    my $msg = join("\n",
        qq|----------- REQUEST ----------|,
        " "x20 . qq|--- Method |.$self->req->method,
        " "x20 . qq|--- Route: |.$self->url_for,
        " "x20 . qq|--- Name:  |.$self->current_route,
        " "x20 . qq|--- Params |,
        @plines,
        " "x20 . qq|--- JSON|,
        @jlines,
        " "x20 . qq|--- user  : $user|,
        " "x20 . qq|--- ipaddr: |.$self->remote_addr,
        " "x20 . qq|---------------------|,
    );
    $self->log->debug($msg);
}

1;
