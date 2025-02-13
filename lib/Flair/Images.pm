package Flair::Images;

use Mojo::Base -base, -signatures;
use Mojo::UserAgent;
use Data::Dumper::Concise;
use HTML::Element;
use MIME::Base64;
use Digest::MD5 qw(md5_hex);

has scot_version => sub { 3; };
has insec   => sub {1;};
has download_dir => '/tmp';
has 'log';
has 'scotapi';
has 'config';

# scan flair text for embedded images
# either data:uri or <img>
# replace those images 

sub process ($self, $tree) {
    
    my @images_in_tree  = @{$tree->extract_links('img')};
    my $replaced        = 0;

    foreach my $image (@images_in_tree) {
        # ref
        # my ($link, $element, $attr, $tag) = @$image;
        next if $self->already_cached($image);
        next if $self->uri_whitelisted($image);

        my $new_image_file = $self->obtain_image($image);
        next if (! defined $new_image_file);

        my $new_uri = $self->upload_to_scot($new_image_file);
        if (ref($new_uri) and $new_uri->{error}) {
            $self->log->error("Failed to replace image: ".$new_uri->{error});
            next;
        }
        $self->rewrite_img_element($image, $new_uri);
        $replaced++;
    }
    return $replaced;
}

sub already_cached ($self, $image) {
    my $link = $image->[0];

    $self->log->debug("Looking at link = $link");

    if ($link =~ /\/api\/v1\/file\/download\//) {
        $self->log->debug("Found an already uploaded scot file");
        return 1;
    }
    return;
}

sub uri_whitelisted ($self, $image) {
    # TODO: implement a whitelist
    return undef;
}

sub obtain_image ($self, $image) {
    my ($link, $element, $attr, $tag) = @{$image};
    if ($link eq "") {
        # src was stripped by a sanitizer?
        $self->log->debug("img src sanitized, unable to further process");
        return undef;
    }
    return ($link =~ m/^data:image/ ) ? $self->convert_data_uri($image)
                                      : $self->download_image($image);
}

sub convert_data_uri ($self, $image) {
    my $uri = $image->[0];
    my ($mime, $encoding, $data) = ($uri =~ m/^data:(.*);(.*),(.*)$/);
    my ($type, $ext)             = split('/', $mime);
    my $decoded                  = decode_base64($data);
    my $md5                      = md5_hex($decoded);
    my $newfile                  = $self->download_dir . "/$md5.$ext";
    if ( $self->file_exists($newfile) ) {
        return $newfile;
    }
    open my $fh, ">", "$newfile" or die $!;
    binmode $fh;
    print $fh $decoded;
    close $fh;
    $self->log->debug("Converted DataURI into file $newfile");
    return $newfile;
}

sub download_image ($self, $image) {
    my $link    = $image->[0];
    my $ua  = Mojo::UserAgent->new();
    $ua->proxy->detect;
    my $insec   = $self->insec;
    my $result  = $ua->insecure($insec)->max_redirects(5)->get($link)->result;

    if ($result->is_success) {
        my $asset   = $result->content->asset;
        my $md5     = md5_hex($asset->slurp);
        my $ext     = $self->get_extension($link);
        my $newfile = $self->download_dir . "/$md5.$ext";
        if ( $self->file_exists($newfile) ) {
            return $newfile;
        }
        $asset->move_to($newfile);
        $self->log->debug("Downloaded $link to file $newfile");
        return $newfile;
    }
    return undef;
}

sub get_extension ($self, $link) {
    my $last    = (split('/', $link))[-1];   # get everything after last /
    my $strip   = (split(/\?/, $last))[0];   # strip ?foo=bar&boom=baz from end
    my $ext     = (split(/\./, $strip))[-1]; # get file extention 
    return $ext;
}

sub file_exists ($self, $filename) {
    return -r $filename;
}

sub upload_to_scot ($self, $image) {
    my $id      = $self->scotapi->upload_file_scot4($image);
    if ( ref($id) and defined $id->{error} ) {
        return $id; # bubble the error up
    }
    my $baseurl = $self->config->{scotapi}->{frontend_accessible_root_uri};
    my $fullurl = "/api/v1/file/download/$id";
    $self->log->debug("uploaded $image new url is $fullurl");
    return $fullurl;
}


sub rewrite_img_element($self, $image, $new_uri) {
    my $link    = $image->[0];
    my $element = $image->[1];
    my $new_alt = $self->get_alt($link, $element);
    my $new_element = HTML::Element->new('img',
        'src'   => $new_uri,
        'alt'   => $new_alt,
    );
    $element->replace_with($new_element);
}

sub get_alt ($self, $link, $element) {
    my $orig    = $element->attr('alt') // '';
    my $new = ( $link =~ /^data:/ ) ? 'Cached copy of embedded data uri' 
                                    : "Locally cached copy of $link";
    # $new .= "-$orig-" if defined $orig;
    my $new_alt = "$orig-$new";
    return $new_alt;
}

1;
