#!/usr/bin/env perl6

use lib 'lib';
use lib 't/lib';

use JSON::Tiny;
use Jupyter::Client;
use Jupyter::Kernel;
use Jupyter::Kernel::Paths;
use Jupyter::Kernel::Service;
use Log::Async;

use Test;

my $res;

# Only for dev <- Heavy tests
if %*ENV<P6_JUPYTER_TEST_END_TO_END> {
    # We must make directory for travis
    raku-dir.mkdir;
} else {
    plan :skip-all<Set P6_JUPYTER_TEST_END_TO_END to run these>;
}

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
  "kernel_name": "raku"
}];
my $spec-file = $*TMPDIR.child("kernel_test.json");
$spec-file.spurt($s_connection);
my $spec = from-json($s_connection);

# Launch a new kernel <- run jupyter-kernel.raku
sub spawn-kernel {
    my $lib = $?FILE.IO.parent.sibling('lib').Str;
    my $script = $?FILE.IO.parent.sibling('bin').child('jupyter-kernel.raku').Str;
    return Proc::Async.new("perl6", "-I$lib", $script, $spec-file).start;
}

# Remove all 'GREP-TEST' in history <- run perl6
sub clean-history {
    my $res = '';
    my rule todel { GREP\-TEST };
    for history-file.lines -> $line {
        $res ~= $line ~ "\n" unless $line ~~ / <todel> /;
    }
    history-file.spurt($res);
}

sub spawn-both {
    my $proc1 = spawn-kernel;
    my $client1 = Jupyter::Client.new(:$spec);
    return ($client1, $proc1);
}

# Test types
my ($cl, $ke) = spawn-both;
is $cl.qa('my $a = "GREP-TEST"; 42'), '42', 'Int';
is $cl.qa(42), '42', 'Int';
is $cl.qa('my $a = "GREP-TEST"; 1/2'), '0.5', 'Rat';
is $cl.qa('my $a = "GREP-TEST"; "toto"'), 'toto', 'Str';
is $cl.qa('my $a = "GREP-TEST"; [1, 2, 3]'), '[1 2 3]', 'Array';
is $cl.qa('my $a = "GREP-TEST"; {   1 => 2, 3 =>    4}'), '{1 => 2, 3 => 4}', 'Hash';
$cl.wait-history;
is $cl.qa('my $a = "GREP-TEST";'), 'GREP-TEST', 'History Pre';
$cl.wait-shutdown;
await $ke;

# Test history
($cl, $ke) = spawn-both;
my $hist = $cl.wait-history;
my $last-cmd = $hist<content><history>[*-1][2];
is $last-cmd, 'my $a = "GREP-TEST";', 'History Post';
$cl.wait-shutdown;
await $ke;

## Clean history file
clean-history;

done-testing;
