#!/usr/bin/env perl
use Mojo::Base -strict;
use strict;
use warnings;

use Test::More;
use Data::Dumper::Concise;
use DateTime;
use Log::Log4perl;
use lib './lib','../lib';
use Flair::ImgGrab;
use Flair::Util::Log;

log_init('testlog.conf');
my $log = get_logger('Flair');

$log->info("$0 begins");

#my $file = find_rel_dir('etc/testlog.conf');
#say $file;
#Log::Log4perl::init($file);
#my $log  = Log::Log4perl->get_logger();

my $config  = {
    insecure        => 0,
    download_root   => '/tmp/flairtest',
};

system("rm -rf $config->{download_root}");

my $ig = Flair::ImgGrab->new(
    log     => $log,
    config  => $config,
);

my $uri     = "https://www.sandia.gov/app/uploads/sites/72/2021/06/scot.png";
my $year    = DateTime->now()->year;
my $dest    = "/tmp/$year/event/123";

my $asset = $ig->get_image($uri);

is(ref($asset), "Mojo::Asset::File", "Got a File Asset");

my $new_name = $ig->build_file_hashname($asset, $uri);
is($new_name, "60a52cc8fc4cc6bf674ff5a34a69c204.png", "Got proper new hash based filename");


my $new_file = $ig->build_new_filename($asset, $uri, $dest);
is ($new_file, "$dest/60a52cc8fc4cc6bf674ff5a34a69c204.png", "Got propper fqn");

$ig->ensure_storage_dir($new_file);

ok(-d $dest, "Created storage dir");

$ig->save_asset($asset, $new_file);

ok(-e $new_file, "New File is in new location");

done_testing();
exit 0;





sub find_rel_dir {
    my $target = shift;
    my @path    = ();

    while (not -r join('/', @path, $target)) {
        push @path, '..';
    }
    return join('/', @path, $target);
}
