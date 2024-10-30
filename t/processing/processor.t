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
use Flair::Processor;
use Flair::Util::Log;
use File::Slurp;
use Digest::MD5 qw(md5_hex);
use Mojo::Pg;
use HTML::Element;
use HTML::TreeBuilder;

log_init('testlog.conf');
my $log = get_logger('Flair');
$log->info("$0 begins");

my $config  = {
    image_root  => '/tmp/flairtest',
    scot_image_root     => '/cached_images',
    image_store_dir     => '/tmp/images',
    flair_servername    => 'localhost',
    pguri   => 'postgresql://flairtest:flair1234@localhost:5432/flairtest',
    model   => {
        regex => {
            default_list_options => {
                fields  => ['*'],
                where   => [],
                order   => [ '-id' ],
                limit   => 50,
                offset  => 0,
            },
            default_fetch_options   => {
                fields  => ['*'],
                where   => [],
                order   => [ '-id' ],
                limit   => 1,
                offset  => 0,
            },
        },
    },
};

my $pg  = Mojo::Pg->new($config->{pguri});
$pg->migrations->from_file('../../etc/flair.pg.sql')->migrate(0)->migrate;
system("../../bin/load_core_regexes.pl");

my $proc = Flair::Processor->new(log => $log, config => $config);
ok(defined $proc, "Processor instantiated");

ok ($proc->wrapq("foo") eq "\"foo\"", "wrapq works");
ok ($proc->stringify_array(["foo", "bar", "boom"]) eq '["foo", "bar", "boom"]', "stringify_array works");

my @a = $proc->arrayify_string('["foo", "bar", "boom"]');
my @e = ("foo", "bar", "boom");
cmp_deeply(\@a, \@e, "arrayify worked");

# test input is not valid
my @input = ({
    type        => "alertgroup",
    id          => 1,
    data        => [ "one", "two", "three" ],
});
is($proc->validate_data(@input), undef, "Detected invalid input for Alertgroup");

$input[0]->{type} = "entry";
$input[0]->{data} = [ { foo => 1 } ];
is($proc->validate_data(@input), undef, "Detected invalid data in Entry");

$input[0]->{data} = [ "now is the time for all good men..."];
ok($proc->validate_data(@input), "Good input for Entry");

$input[0]->{id} = "foo";
is($proc->validate_data(@input), undef, "Detected bad id");



my @args = ( {
    type  => "entry",
    id          => 1230,
    data    => [
        'this is a string to flair',
    ],
});

my $got = $proc->validate_data(@args);
my $exp = {
    type => 'entry',
    data       => $args[0]->{data},
    id         => $args[0]->{id},
};
cmp_deeply($got, $exp, "Got valid data from validation");


# build html tree
my $html    = '<html><head><title>Foo</title></head><body><ul><li>one</li></ul></body></html>';
is (ref($proc->build_html_tree($html)), 'HTML::Element', 'Build a tree');

# test already_cached
my $uri = "http://foo.com/bar.png";
is ($proc->already_cached($uri), '', "Correctly identified not cached uri");
$uri = '/cached_images/bar.png';
is ($proc->already_cached($uri), 1, "Correctly identified cached uri");

# test build_new_uri
is ($proc->build_new_uri('/opt/images/abcdef1234.png'),'/cached_images/abcdef1234.png', 'built the new uri correctly') ;

# test create_file
# TODO:

# get_store_dir
my $year = DateTime->now->year;
system("rm -rf ".$config->{image_store_dir});
ok (! -d $config->{image_store_dir}."/$year", "Directory was missing");
is ($proc->get_store_dir(), $config->{image_store_dir} . "/$year", "Got Dir");
ok (-d $config->{image_store_dir}."/$year", "Directory was created");

# create db_file_rec
my $fid = $proc->create_db_file_rec("/tmp/images/foo.jpg");
ok ($fid == 1, "Got file_id for created file record");

# local uri
my $local_filename   = "/opt/images/foo.jpg";
my $local_uri = $proc->local_uri($local_filename);
my $file_id = 2;
ok ($local_uri eq "https://".$config->{flair_servername}."/images/$file_id", "Got uri");

# is_leaf_node
my $element = HTML::Element->new('p');
is ($proc->is_leaf_node($element), '', "Not a leaf");
ok ($proc->is_leaf_node("foobar"), "Is a leaf");

# predfiend entity
my $pdedb = {};
is ($proc->is_predefined_entity($element, $pdedb), undef, "Not predefined flair");
$element = HTML::Element->new('span',
    class   => 'entity ipaddr',
    'data-entity-type'    => 'ipaddr',
    'data-entity-value'   => '10.10.10.1',
);

ok($proc->is_predefined_entity($element, $pdedb), "Predefined");
cmp_deeply($pdedb, { 'ipaddr' => { '10.10.10.1' => 1 } }, "Edb correct");

$html    = q{<div>This is some text</div> };

my $tree    = $proc->build_html_tree($html);
ok(ref($tree) eq "HTML::Element", "Build a tree");

my ($fhtml, $ptext)   = $proc->output_tree($tree);
ok($fhtml eq '<div>This is some text</div>', "Flair html ok");
ok($ptext eq 'This is some text', "Plain text ok");

$html   = q{<html><head><title>foobar</title></head><body><p>foobar</p></head></html>};
$tree    = $proc->build_html_tree($html);
my ($f,$p) = $proc->output_tree($tree);
ok($f eq '<div><p>foobar</div>', "Flair html ok");
ok($p eq 'foobar', "Plain text ok");

# merge edb test
my $existing = { 'ipaddr' => { '10.10.10.1' => 1 } };
my $new      = { 'domain' => { 'foo.com' => 1 } };
$proc->merge_edb($existing, $new);
my $exp_edb = {
    'ipaddr' => { '10.10.10.1' => 1 } ,
    'domain' => { 'foo.com' => 1},
};
cmp_deeply($existing, $exp_edb, "EDB merged 1 new item");

my $adone = { 'ipaddr' => { '10.10.10.1' => 1 }};

$proc->merge_edb($existing, $adone);
$exp_edb = {
    'ipaddr' => { '10.10.10.1' => 2 } ,
    'domain' => { 'foo.com' => 1},
};
cmp_deeply($existing, $exp_edb, "EDB merged 1 existing item");

# sparkline test
my $spark = q{["##__SPARKLINE__##","0","1","2","1","0"]};

ok($proc->contains_sparkline($spark), "Found sparkline");

my $svg = $proc->process_sparkline($spark);
$exp = '<svg height="12" viewBox="0 -11 7 12" width="7" xmlns="http://www.w3.org/2000/svg"><polyline fill="none" points="0,-5 2,-10 4,-5 6,0" stroke="blue" stroke-linecap="round" stroke-width="1" /></svg>';

is($svg, $exp, "Sparkline Array corrent");
my $sparkstr = '[##__SPARKLINE__##, 0, 1, 2, 1, 0]';
ok($proc->contains_sparkline($sparkstr), "Found sparkline");
$svg = $proc->process_sparkline($sparkstr);
is($svg, $exp, "Sparkline String in element 0 corrent");

$sparkstr = '##__SPARKLINE__##, 0, 1, 2, 1, 0';
ok($proc->contains_sparkline($sparkstr), "Found sparkline");
$svg = $proc->process_sparkline($sparkstr);
is($svg, $exp, "Sparkline String corrent");

$sparkstr = '"##__SPARKLINE__##", "0", "1", "2", "1", "0"';
ok($proc->contains_sparkline($sparkstr), "Found sparkline");
$svg = $proc->process_sparkline($sparkstr);
is($svg, $exp, "Sparkline String corrent");

# get column type
my %coltypetest = (
    'message_id', 'Message_ID',
    'message_id', 'Message-ID',
    'message_id', 'MESSAGE-ID',
    'uuid1',      'lbscanid',
    'uuid1',        'scanid',
    'filename',     'attachments',
    'filename',     'attachment-name',
    'sentinel',     'sentinel_incident_url',
    'normal',       'foobar',
);

while (my ($type, $col) = each %coltypetest) {
    is ($proc->get_column_type($col), $type, "$col returned correct type $type");
}

# genspan
is ( $proc->genspan('foo', 'bar'), '<span class="entity foo" data-entity-type="foo" data-entity-value="bar">bar</span>', "Genspan works");

# sentinel test
is ( $proc->create_sentinel_flair('https://foo.com'), '<a href="https://foo.com" target="_blank"><img alt="view in azure sentinel" src="/images/azure-sentinel.png" /></a>', 'flair sentinel works');

# prepare parser
system('../../bin/load_core_regexes.pl');
$proc->init_parser();

# flair cell
my $alert   = { 
    id  => 1, 
    alertgroup => 10, 
    data => { 
        foo => q{["sandia.gov", "scotdemo.com"]} 
    } 
};

my $cell_results = $proc->flair_cell($alert, "foo", $alert->{data}->{foo}, {});
my $exp_flair   = ['<span class="entity domain" data-entity-type="domain" data-entity-value="sandia.gov">sandia.gov</span>', '<span class="entity domain" data-entity-type="domain" data-entity-value="scotdemo.com">scotdemo.com</span>'];
my $exp_text    = ["sandia.gov", "scotdemo.com"];
is ($cell_results->{entities}->{domain}->{'sandia.gov'}, 1, "EDB 1 correct");
is ($cell_results->{entities}->{domain}->{'scotdemo.com'}, 1, "EDB 2 correct");
cmp_deeply ($cell_results->{flair}, $exp_flair, "Got expected flair");
cmp_deeply ($cell_results->{text}, $exp_text, "Got expected text");

# flair alert
$alert  = {
    id          => 10,
    alertgroup  => 100,
    columns     => [ 
        'foo', 'sparkline', 'filename', 'sentinel', 'lbscanid', 'message-id' 
    ],
    data        => {
        foo         => [ '10.10.10.1', '192.168.5.1' ],
        filename    => [ 'foo.exe', 'bar.bat', 'boom.py' ],
        sentinel    => [ 'https://scotdemo.com' ],
        lbscanid    => [ 'abcdef12345689' ],
        'message-id'=> [ '<adsfadsfadsfa@foo.com>' ],
    }
};

$got = $proc->flair_alert($alert,{});
my $expected    = {
    entities    => {
        domain  => {
            'scotdemo.com'  => 1,
        },
        file    => {
            'bar.bat'   => 1,
            'boom.py'   => 1,
            'foo.exe'   => 1,
        },
        ipaddr  => {
            '10.10.10.1'    => 1,
            '192.168.5.1'   => 1,
        },
        message_id => {
            '<adsfadsfadsfa@foo.com>' => 1,
        },
        uuid1 => {
            abcdef12345689 => 1,
        },
    },
    flair_data => { 
        filename => [
            '<span class="entity file" data-entity-type="file" data-entity-value="foo.exe">foo.exe</span>',
            '<span class="entity file" data-entity-type="file" data-entity-value="bar.bat">bar.bat</span>',
            '<span class="entity file" data-entity-type="file" data-entity-value="boom.py">boom.py</span>',
    ],
    foo => [
      '<span class="entity ipaddr" data-entity-type="ipaddr" data-entity-value="10.10.10.1">10.10.10.1</span>',
      '<span class="entity ipaddr" data-entity-type="ipaddr" data-entity-value="192.168.5.1">192.168.5.1</span>',
    ],
    lbscanid => [
      '<span class="entity uuid1" data-entity-type="uuid1" data-entity-value="abcdef12345689">abcdef12345689</span>',
    ],
    "message-id" => [
      '<span class="entity message_id" data-entity-type="message_id" data-entity-value="<adsfadsfadsfa@foo.com>"><adsfadsfadsfa@foo.com></span>',
    ],
    sentinel => [
      'https://<span class="entity domain" data-entity-type="domain" data-entity-value="scotdemo.com">scotdemo.com</span>',
    ],
  },
  id => 10,
  text_data => {
    filename => [
      "foo.exe",
      "bar.bat",
      "boom.py",
    ],
    foo => [
      "10.10.10.1",
      "192.168.5.1",
    ],
    lbscanid => [
      "abcdef12345689",
    ],
    "message-id" => [
      '<adsfadsfadsfa@foo.com>',
    ],
    sentinel => [
      "https://scotdemo.com",
    ],
  },
};

cmp_deeply($got, $expected, "Alert row correctly flaired");
print Dumper($got);

my $alertgroup  = {
    id      => 100,
    data    => [
        $alert,
    ]
};

my $agexp = {
    id      => $alertgroup->{id},
    type    => 'alertgroup',
    alerts  => [
        $expected,
    ],
    entities    => $expected->{entities},
};

my $gotag = $proc->process_alertgroup(undef, $alertgroup);
cmp_deeply($gotag, $agexp, "Alertgroup correctly flaired");
# say Dumper($gotag);

# process an alert with an invalid domain name
$log->debug("invalid domain test");

my $inval = {
    id  => 600,
    columns => [ 'foo' ],
    data => { 
        foo => q{["sandia.giv", "scotdemo.foo"]} 
    },
};
my $invag = {
    id  => 700,
    type    => 'alertgroup',
    data    => [
        $inval
    ],
};
my $invexp = {
    alerts  => [{
        entities => {
            domain  => {
                'scotdemo.foo' => 1,
            },
        },
        id  => 600,
        flair_data => {
            foo => [ 'sandia.giv', ,'<span class="entity domain" data-entity-type="domain" data-entity-value="scotdemo.foo">scotdemo.foo</span>' ],
        },
        text_data   => {
            foo => [ 'sandia.giv', 'scotdemo.foo' ],
        },
    }],
    entities => {
        domain => {
            'scotdemo.foo' => 1,
        }
    },
    id => 700,
    type => 'alertgroup',
};
            
$gotag = $proc->process_alertgroup(undef, $invag);
cmp_deeply($gotag, $invexp, "Invalid domain rejected");

done_testing();
exit 0;
