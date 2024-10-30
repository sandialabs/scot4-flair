#!/usr/bin/env perl
use Mojo::Base -strict;
use strict;
use warnings;

use Test::More;
use Test::Most;
use Data::Dumper::Concise;
use DateTime;
use Log::Log4perl;
use lib '../../lib';
use Flair::Parser;
use Flair::Util::Log;
use File::Slurp;
use Digest::MD5 qw(md5_hex);

log_init('testlog.conf');
my $log = get_logger('Flair');
$log->info("$0 begins");

my $config  = {
    image_root  => '/tmp/flairtest',
};

my $parser = Flair::Parser->new(log => $log);

ok(defined $parser, "Parser instantiated");

my $regexes = [
    {
        name            => 'cve detection',
        description     => 'Find CVE-YYYY-XXXX in text',
        match           => '\b (CVE-(\d{4})-(\d{4,})) \b',
        regex           => qr{\b (CVE-(\d{4})-(\d{4,})) \b}xims,
        entity_type     => 'cve',
        regex_type      => 'core',
        re_order        => 1,
        multiword       => 0,
    },
];

$parser->regexes($regexes);

my $text    = 'One Two CVE-2022-0001 Three Four';
my $expected= 'One Two <span class="entity cve" data-entity-type="cve" data-entity-value="CVE-2022-0001">CVE-2022-0001</span> Three Four';
my $edb     = {};
my @new     = $parser->find_flair($text, $edb);
my $got     = join('', map { (ref $_) ?  $_->as_HTML('') : $_ } @new);

is($got, $expected, "Flaired Text correct");
cmp_deeply($edb, { entities => { cve => { "CVE-2022-0001" => 1 } } }, "Edb Correct");


done_testing();
exit 0;
