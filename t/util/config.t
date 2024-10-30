#!/usr/bin/env perl

use Test::More;
use Test::Deep;
use lib '../../lib';

use Flair::Util::Config;
use Data::Dumper::Concise;

my $fuc     = Flair::Util::Config->new();
my $config  = $fuc->get_config("flair.conf");

my $expected = {
  default_expiration => 14400,
  hypnotoad => {
    clients => 1,
    heartbeat_timeout => 40,
    listen => [
      "http://localhost:3001?reuse=1",
    ],
    pidfile => "/var/run/flair.hypno.pid",
    proxy => 1,
    workers => 5,
  },
  logconf => "log.conf",
  mode => "development",
  model => {
    regex => {
      default_fetch_options => {
        fields => [
          "*",
        ],
        limit => 1,
        offset => 0,
        order => [
          "-id",
        ],
        where => [],
      },
      default_list_options => {
        fields => [
          "*",
        ],
        limit => 50,
        offset => 0,
        order => [
          "-id",
        ],
        where => [],
      },
    },
  },
  pguri => "postgresql://flairtest:flair1234\@localhost:5432/flairtest",
  secrets => [
    "f00b\@r4w1n",
    "dafasdfasdf",
  ],
  version => "1.0",
};

cmp_deeply($config, $expected, "Correctly parsed config");
done_testing();

