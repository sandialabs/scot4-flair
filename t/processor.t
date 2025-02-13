#!/opt/perl/bin/perl

use Mojo::Base -strict;
use Test::Most;
use Test::Mojo;
use Data::Dumper::Concise;
use HTML::Element;

use lib '../lib';
use Flair::Processor;
use Flair::Util::Log;
use Flair::Util::HTML;
use Flair::Util::Sparkline;
use Flair::Db;

system("rm -f /var/flair/test.db");

log_init('testlog.conf');
my $log = get_logger('Flair');
$log->info("$0 begins");

my $config = {
    scotapi => {
        user    => '',
        pass    => '',
        apikey  => '',
        uri_root    => 'https://scot.watermelon.com',
        insecure    => 1,
    },
    database    => {
        dbtype  => 'sqlite',
        dbfile  => '/var/flair/test.db',
        uri     => 'file:/var/flair/test.db', 
        model   => {
            regex   => {},
            metrics => {},
            admins  => {},
            jobs    => {},
        },
        migration   => '../etc/test.sqlite.sql',
    },
};

$ENV{'S4FLAIR_DB_FILE'} = $config->{database}->{dbfile};
$ENV{'S4FLAIR_DB_URI'} = $config->{database}->{uri};
$ENV{'S4FLAIR_DB_MIGRATION'} = $config->{database}->{migration};
$ENV{S4FLAIR_JOB_TEST} = 1;

my $migfile = $config->{database}->{migration};
my $db  = Flair::Db->new(log => $log, config  => $config->{database});
is (ref($db), "Flair::Db", "Got DB connection") or die "unable to connect to db";
ok ($db->dbh->migrations->from_file($migfile)->migrate(0)->migrate, 
    "Migrated database") or die "Unable to intialize database";

# leaving out scotapi for now, will test seperately

my $t = Test::Mojo->new('Flair');
my $proc = Flair::Processor->new(log => $log, db => $db, config => $config, minion=>$t->app->minion);
is (ref($proc), "Flair::Processor", "instatiated processor") or die "Failed to instantiate Processor";

 bulk_tests();
 done_testing();
 exit 0;

 data_validation_tests();
 leaf_node_detection();
 predefined_entity_detection();
 detect_skippable_columns();
 stringify_array();
 arrayify_string();
 merge_edb();
 html_tree();
 column_types();
 xss_tests();
 node_is_span_detection(); 
 node_is_noflair_section();
 node_flair_override_section();
 sparkline_tests();
 multi_row_spark_alert();
 images_in_alerts();

sub xss_tests {
    my $html    = q{<p>&lt;script&gt;alert(1);&lt;/script%gt;</p>};
    my $tree    = build_html_tree($html);
    my ($fhtml, $ptext) = output_tree_html($tree);
    print "HTML  = $html\n";
    print "FLAIR = $fhtml\n";
    print "PLAIN = $ptext\n";
}

sub html_tree {
    my $html    = q{<div>This is some text</div>};
    my $tree    = build_html_tree($html);
    ok(ref($tree) eq "HTML::Element", "Build a tree");

    my ($fhtml, $ptext)   = output_tree_html($tree);
    ok($fhtml eq '<div>This is some text</div>', "Flair html ok");
    ok($ptext eq 'This is some text', "Plain text ok");

    $html   = q{<html><head><title>foobar</title></head><body><p>foobar</p></head></html>};
    $tree    = build_html_tree($html);
    my ($f,$p) = output_tree_html($tree);
    ok($f eq '<div><p>foobar</div>', "Flair html ok");
    ok($p eq 'foobar', "Plain text ok");
}

sub column_types {
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
}

sub merge_edb {
    my $existing = { 'ipaddr' => { '10.10.10.1' => 1 } };
    my $new      = { 'domain' => { 'foo.com' => 1 } };
    $proc->merge_edb($existing, $new);
    my $exp_edb = {
        'ipaddr' => { '10.10.10.1' => 1 } ,
        'domain' => { 'foo.com' => 1},
    };
    cmp_deeply($existing, $exp_edb, "EDB merged 1 new item");
}


sub arrayify_string {
    my $s = '["one", "two", "three"]';
    my @a = $proc->arrayify_string($s);
    is (scalar(@a), 3, "Got correct number of elements from arrayified string")
    or die "Failed to arrayify string";
    is ($a[0], "one", "Got correct item at position 0")
    or die "Incorrect item at position 0";
    is ($a[1], "two", "Got correct item at position 2")
    or die "Incorrect item at position 2";
    is ($a[2], "three", "Got correct item at position 3")
    or die "Incorrect item at position 3";
}

sub stringify_array {
    my $a = [ qw(one two three) ];
    my $s = $proc->stringify_array($a);
    is ($s, '["one", "two", "three"]', "Correctly Stringified Array")
    or die "Failed to stringify array";
}

sub detect_skippable_columns {
    ok($proc->is_skippable_column("columns"), "Detected skippable column: columns")
    or die "Failed to detect column: columns";
    ok($proc->is_skippable_column("_raw"), "Detected skippable column: _raw")
    or die "Failed to detect column: _raw";
    ok($proc->is_skippable_column("search"), "Detected skippable column: search")
    or die "Failed to detect column: search";
}

sub predefined_entity_detection {
    my $node    = HTML::Element->new('span',
        class   => "entity ipaddr",
        'data-entity-type'  => "ipaddr",
        'data-entity-value' => "10.10.10.10",
    );
    my $edb     = {};
    ok ($proc->is_predefined_entity($node, $edb), "Found predefined entity")
    or die "Missed predefined entity";
    cmp_deeply($edb, {ipaddr => { '10.10.10.10' => 1 }}, "EDB updated correctly")
    or die "Incorrect update of edb";
}

sub leaf_node_detection {
    my $leaf_element    = HTML::Element->new(
        'p',
    );
    $leaf_element->push_content("fall like a leaf");

    my @content = $leaf_element->content_list;
    my $child   = $content[0];
    ok($proc->is_leaf_node($child), "Found Leaf Node") or die "Failed to find leaf node";

    my $non_leaf_element = HTML::Element->new(
        'div',
    );
    my $sibling_element = HTML::Element->new(
        'div', 
    );
    $sibling_element->push_content("testing is fun");
    $non_leaf_element->push_content($sibling_element,$leaf_element);
    @content = $non_leaf_element->content_list;
    $child   = $content[0];
    ok(! $proc->is_leaf_node($child), "Found non Leaf Node") or die "Found leaf, when there was none";
}

sub node_is_span_detection {
    my $not_span_node    = HTML::Element->new('p');
    $not_span_node->push_content("foobar");

    my $span_node   = HTML::Element->new('span');
    $span_node->push_content("this is a span");

    ok(! $proc->node_is_span($not_span_node), "correctly did not find node for non-span node");
    ok($proc->node_is_span($span_node), "correctly found a span");
}

sub node_is_noflair_section {
    my $noflair1 = HTML::Element->new('noflair');
    $noflair1->push_content('do not flair this');

    ok($proc->is_no_flair_span($noflair1), "Correctly found <noflair/>");

    my $noflair2 = HTML::Element->new('span', class => 'noflair');
    $noflair2->push_content("also do not flair");

    print "noflair2 = ".$noflair2->dump."\n";

    ok($proc->is_no_flair_span($noflair2), "Correctly found <span class=\"noflair\">");
}

sub node_flair_override_section {
    my $nonsection = HTML::Element->new('span', 'class' => 'foobar');
    $nonsection->push_content('zoooooooo');
    my $section = HTML::Element->new('span', class => "flairoverride", 'data-entity-type' => "foobar");
    $section->push_content("boombaz");

    ok (!$proc->is_flair_override_span($nonsection), "correctly did not detect override in normal span");
    ok ($proc->is_flair_override_span($section), "Detected flair override correctly");

    my $edb = {};
    my $tedb    = {
        foobar  => { boombaz => 1 }
    };
    my $span = $proc->extract_flair_override($section, $edb);

    ok (ref($span) eq "HTML::Element", "Got an HTML::Element");
    ok ($span->tag eq "span", "Got a Span");
    ok ($span->attr('class') eq 'entity foobar', 'Got right classes');
    ok ($span->attr('data-entity-type') eq "foobar", "Got right data-entity-type");
    ok ($span->attr('data-entity-value') eq "boombaz", "Got right entity-value");

    cmp_deeply($edb, $tedb, "populated edb correctly");

}

sub data_validation_tests {
    my @valid_request_data1 = ({
        type    => 'alertgroup',
        id      => 1234,
        data    => {
            alerts => [
                {alert_id => 1, columns => [qw(foo bar boom)], data => { foo => 1, bar => 2, boom => 3 }},
                {alert_id => 2, columns => [qw(foo bar boom)], data => { foo => 7, bar => 8, boom => 9 }},
            ],
        },
    });
    ok ($proc->validate_data(@valid_request_data1), "Valid data passed") 
    or die "marked valid data invalid";

    @valid_request_data1 = ({
        type    => 'entry',
        id      => 1234,
        data    => 'this is a test of the emergency broadcast alert',
    });
    ok ($proc->validate_data(@valid_request_data1), "Valid data passed") 
    or die "marked valid data invalid";

    my @invalid_request_data1 = ({
        type    => 'foo',
        id      => 1234,
        data    => 'foobar',
    });
    ok (!$proc->validate_data(@invalid_request_data1), "Detected invalid data") 
    or die "Passed invalid data";

    @invalid_request_data1 = ({
        type    => 'alertgroup',
        id      => 1234,
        data    => 'foobar',
    });
    ok (!$proc->validate_data(@invalid_request_data1), "Detected invalid data") 
    or die "Passed invalid data";


    @invalid_request_data1 = ({
        type    => 'entry',
        id      => 1234,
        data    => { foo => 'bar' },
    });
    ok (!$proc->validate_data(@invalid_request_data1), "Detected invalid data") 
    or die "Passed invalid data";
}

sub sparkline_tests {
    my $data = <<'EOF';
MULTILINE_SPARKLINE_TABLE
198.251.83.27,11,##__SPARKLINE__## 11 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0,lc_nm_udp:zeek_conn_scan:dns_answer:zeek_conn_est:lc_ca_udp:lc_ca_tcp:lc_nm_tcp
69.46.15.151,1,##__SPARKLINE__## 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0,lc_ca_udp
dns102.registrar-servers.com,365,##__SPARKLINE__## 162 3 6 5 7 6 5 3 6 7 4 2 2 4 0 1 6 6 3 1 1 2 6 3 7 8 2 0 0 2 4 5 3 3 1 7 7 5 7 8 6 4 3 6 5 5 3 4 1 6,dns_query:dns_answer:lc_nm_dns:lc_ca_dns
EOF

    ok (contains_multi_row_sparklines($data), "Found multiline spark table");
    is (contains_multi_row_sparklines('##__SPARKLINE__##'), undef, "not multi-line sparkline");
    is (contains_sparkline('##__SPARKLINE__##'), 1, "not multi-line sparkline, is singleline");

    my $table = $proc->build_multi_sparkline_table($data);

    say $table;

}

sub multi_row_spark_alert {
    my $alert = { row => {
        "Intel_id"  => "5749", 
        "Subject"   => "LRI alert test", 
        "Tags"      => ["test"], 
        "Sources"   => ["mandiant"], 
        "LRI Hit Information" => <<"EOF"
MULTILINE_SPARKLINE_TABLE
dns101.registrar-servers.com,365,##__SPARKLINE__## 162 4 5 6 7 5 4 4 6 6 5 0 3 3 0 2 6 5 3 1 1 4 4 5 7 7 1 0 0 3 4 6 1 3 3 6 7 6 7 8 5 4 3 7 4 4 4 4 2 6,lc_nm_dns:dns_answer:lc_ca_dns:dns_query
146.70.53.153,4,##__SPARKLINE__## 3 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0,lc_nm_udp:lc_nm_tcp:zeek_conn_scan
EOF
    }};
    my $fp;
    my $result  = $proc->flair_alert($alert, $fp);
    print Dumper($result);
    is ($result->{entities}->{domain}->{'dns101.registrar-servers.com'}, 1, "Domain Entity found");
    my $expected_lri = '<div><table><tr></tr><tr><th>IOC</th><th>Indices</th><th>Hits</th><th>Sparkline</th></tr><tr><td style="border: 1px solid black; border-collapse: collapse;"><span class="entity domain" data-entity-type="domain" data-entity-value="dns101.registrar-servers.com">dns101.registrar-servers.com</span></td><td style="border: 1px solid black; border-collapse: collapse;">lc_nm_dns<br />dns_answer<br />lc_ca_dns<br />dns_query</td><td style="border: 1px solid black; border-collapse: collapse;">365</td><td style="border: 1px solid black; border-collapse: collapse;"><svg height="12" viewbox="0 -11 99 12" width="99" xmlns="http://www.w3.org/2000/svg"><polyline fill="none" points="0,-10 2,-0.25 4,-0.31 6,-0.37 8,-0.43 10,-0.31 12,-0.25 14,-0.25 16,-0.37 18,-0.37 20,-0.31 22,0 24,-0.19 26,-0.19 28,0 30,-0.12 32,-0.37 34,-0.31 36,-0.19 38,-0.06 40,-0.06 42,-0.25 44,-0.25 46,-0.31 48,-0.43 50,-0.43 52,-0.06 54,0 56,0 58,-0.19 60,-0.25 62,-0.37 64,-0.06 66,-0.19 68,-0.19 70,-0.37 72,-0.43 74,-0.37 76,-0.43 78,-0.49 80,-0.31 82,-0.25 84,-0.19 86,-0.43 88,-0.25 90,-0.25 92,-0.25 94,-0.25 96,-0.12 98,-0.37" stroke="blue" stroke-linecap="round" stroke-width="1"></polyline></svg></td></tr><tr><td style="border: 1px solid black; border-collapse: collapse;"><span class="entity ipaddr" data-entity-type="ipaddr" data-entity-value="146.70.53.153">146.70.53.153</span></td><td style="border: 1px solid black; border-collapse: collapse;">lc_nm_udp<br />lc_nm_tcp<br />zeek_conn_scan</td><td style="border: 1px solid black; border-collapse: collapse;">4</td><td style="border: 1px solid black; border-collapse: collapse;"><svg height="12" viewbox="0 -11 99 12" width="99" xmlns="http://www.w3.org/2000/svg"><polyline fill="none" points="0,-10 2,0 4,0 6,0 8,0 10,0 12,0 14,0 16,0 18,-3.33 20,0 22,0 24,0 26,0 28,0 30,0 32,0 34,0 36,0 38,0 40,0 42,0 44,0 46,0 48,0 50,0 52,0 54,0 56,0 58,0 60,0 62,0 64,0 66,0 68,0 70,0 72,0 74,0 76,0 78,0 80,0 82,0 84,0 86,0 88,0 90,0 92,0 94,0 96,0 98,0" stroke="blue" stroke-linecap="round" stroke-width="1"></polyline></svg></td></tr></table></div>';
    my $got = $result->{flair_data}->{"LRI Hit Information"}->[0];
    is ($expected_lri, $got, "Created table correctly with sparkline");

#    my @e_array = split(//, $expected_lri);
#    my @g_array = split(//, $got);
#
#    for (my $i = 0; $i < scalar(@e_array); $i++) {
#        if ($e_array[$i] eq $g_array[$i]) {
#            print $e_array[$i];
#            next;
#        }
#        print "\n Element $i differs: expected $e_array[$i] got $g_array[$i]\n";
#        last;
#    }
}


sub images_in_alerts {
    my $imgmunger   = Flair::Images->new(log => $log);
    # my $cell   = '<img src="https://www.sandia.gov/app/uploads/sites/72/2021/06/scot.png"/>';
    my $cell   = '<img src="https://images.squarespace-cdn.com/content/v1/52b60f24e4b067a0f59876d1/1587588018088-OEP235P8CDESX3CIAONY/RiosLawLogo.jpg?format=1500w"/>';
    my $tree   = build_html_tree($cell);
    my @images  = @{$tree->extract_links('img')};
    for my $image (@images) {
        # print Dumper($image);
        my $newuri  = "/api/v1/file/download/123";
       $imgmunger->rewrite_img_element($image, $newuri);
    }
    is($tree->as_HTML, '<html><head></head><body><img alt="-Locally cached copy of https://images.squarespace-cdn.com/content/v1/52b60f24e4b067a0f59876d1/1587588018088-OEP235P8CDESX3CIAONY/RiosLawLogo.jpg?format=1500w" src="/api/v1/file/download/123" /></body></html>', 'rewrote img element');
}

sub bulk_tests {
    my @joblist = (
        {
            id      => 100,
            type    => 'alertgroup',
            data    => {
                alerts => [
                    { id => 1, row => { foo => 1, bar => 2, boom => 3, baz => 4 }},
                    { id => 2, row => { foo => 2, bar => 3, boom => 4, baz => 5 }},
                ],
            },
        },
        {
            id      => 101,
            type    => 'alertgroup',
            data    => {
                alerts => [
                    { id => 3, row => { foo => 1, bar => 2, boom => 3, baz => 4 }},
                    { id => 4, row => { foo => 2, bar => 3, boom => 4, baz => 5 }},
                ],
            },
        },
    );

    $proc->enqueue_bulk_jobs((\@joblist,1));
    $t->app->minion->perform_jobs;
}

sub udef_tests {
    $db->regex->create({

    });
}


done_testing();
exit 0;
