#!/opt/perl/bin/perl

use Mojo::Base -strict;
use Test::Most;
use Data::Dumper::Concise;
use HTML::Element;

use lib '../lib';
use Flair::Processor;
use Flair::Util::Log;
use Flair::Util::HTML;
use Flair::Util::Sparkline;
use Flair::Db;

system("rm /var/flair/test.db");

log_init('testlog.conf');
my $log = get_logger('Flair');
$log->info("$0 begins");

my $config = {
    scotapi => {
        user    => '',
        pass    => '',
        apikey  => '',
        uri_root    => '',
        insecure    => 1,
    },
    database    => {
        dbtype  => 'sqlite',
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

my $migfile = $config->{database}->{migration};
my $db  = Flair::Db->new(log => $log, config  => $config->{database});
is (ref($db), "Flair::Db", "Got DB connection") or die "unable to connect to db";
ok ($db->dbh->migrations->from_file($migfile)->migrate(0)->migrate, 
    "Migrated database") or die "Unable to intialize database";

# leaving out scotapi for now, will test seperately

my $proc = Flair::Processor->new(log => $log, db => $db);
is (ref($proc), "Flair::Processor", "instatiated processor") or die "Failed to instantiate Processor";

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
    say Dumper $result;
}


done_testing();
exit 0;
