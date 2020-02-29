#!/usr/bin/env perl6

use lib 'lib';

use JSON::Tiny;
use Jupyter::Client;
use Jupyter::Kernel;
use Jupyter::Kernel::Paths;
use Jupyter::Kernel::Service;
use Log::Async;

use Test;

plan 1;


# Define logger
my $VERBOSE = %*ENV<JUP_VERBOSE>;
my @log;
logger.add-tap: {
    @log.push($_);
    note "# $_<msg>" if $VERBOSE;
};


# Create connection file
my $s_connection = Q[{
  "shell_port": 9099,
  "iopub_port": 9100,
  "stdin_port": 9101,
  "control_port": 9102,
  "hb_port": 9103,
  "ip": "127.0.0.1",
  "key": "abcd",
  "transport": "tcp",
  "signature_scheme": "hmac-sha256",
  "kernel_name": "perl6"
}];
my $spec-file = Jupyter::Kernel::Paths.raku-dir.child("kernel_test.json");
$spec-file.IO.spurt($s_connection);
my $spec = from-json($s_connection);


# Launch a new kernel <- run jupyter-kernel.p6
sub spawn-kernel {
    my $lib = $?FILE.IO.parent.parent.child('lib').Str;
    my $script = $?FILE.IO.parent.parent.child('bin').child('jupyter-kernel.p6').Str;
    return Proc::Async.new("perl6", "-I$lib", $script, $spec-file).start;
}


# Remove all 'GREP-TEST' in history <- run perl6
sub clean-history {
    my $res = '';
    my $file = Jupyter::Kernel::Paths.history-file;
    my rule todel {^ \[ \d+ \, \d+ \, ...GREP\-TEST };
    for $file.lines -> $line {
        $res ~= $line ~ "\n" unless / <todel> /;
    }
    $file.spurt($res);
}


# First execution: Send 'GREP-TEST'
my $proc1 = spawn-kernel;
my $client1 = Jupyter::Client.new(:$spec);
my $ans1 = $client1.wait-request('"GREP-TEST"');
$client1.wait-shutdown;
await $proc1;


# Second execution: Search GREP-TEST in history
my $proc2 = spawn-kernel;
my $client2 = Jupyter::Client.new(:$spec);
my $hist = $client2.wait-history;
my $last-cmd = $hist<content><history>[*-1][2];
$client2.wait-shutdown;
await $proc2;


# Finally Test
is $last-cmd, '"GREP-TEST"', 'history is persistent';


# Clean
clean-history
