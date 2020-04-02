#!/usr/bin/env perl6

use lib 'lib';
use lib 't/lib';

use JSON::Tiny;
use Net::ZMQ4::Constants;
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

my ($cl, $ke) = spawn-both;

# Test types
is $cl.qa('my $a = "GREP-TEST"; 42'), '42', 'Int';
is $cl.qa(42), '42', 'Int';
is $cl.qa('my $a = "GREP-TEST"; 1/2'), '0.5', 'Rat';
is $cl.qa('my $a = "GREP-TEST"; "toto"'), 'toto', 'Str';
is $cl.qa('my $a = "GREP-TEST"; [1, 2, 3]'), '[1 2 3]', 'Array';
is $cl.qa('my $a = "GREP-TEST"; {   1 => 2, 3 =>    4}'), '{1 => 2, 3 => 4}', 'Hash';

# Test order
## 1 Wait request
$cl.wait-request('my $a = "GREP-TEST"; say "Raku Order" gt "Jedy Order"; 42');
## 2 Read stdio, without waiting
my @stdout = $cl.read-stdio(ZMQ_DONTWAIT);
## 3 Check order:
### 3.1 busy
my $msg = @stdout.shift;
is $msg{'header'}{'msg_type'}, 'status', 'Order: 1. type = status';
is $msg{'content'}{'execution_state'}, 'busy', 'Order: 1. content = busy';
### 3.2 stream <- True
$msg = @stdout.shift;
is $msg{'header'}{'msg_type'}, 'stream', 'Order: 2. type = stream';
is $msg{'content'}{'text'}, "True\n", 'Order: 2. content = True\n';
### 3.3 code <- repeat input
$msg = @stdout.shift;
is $msg{'header'}{'msg_type'}, 'execute_input', 'Order: 3. type = execute_input';
is $msg{'content'}{'code'}, 'my $a = "GREP-TEST"; say "Raku Order" gt "Jedy Order"; 42', 'Order: 3. content = Some code';
### 3.4 result <- 42
$msg = @stdout.shift;
is $msg{'header'}{'msg_type'}, 'execute_result', 'Order: 4. type = execute_result';
is $msg{'content'}{'data'}{'text/plain'},  42, 'Order: 4. content = 42';
### 3.5 idle
$msg = @stdout.shift;
is $msg{'header'}{'msg_type'}, 'status', 'Order: 5. type = status';
is $msg{'content'}{'execution_state'}, 'idle', 'Order: 5. content = idle';
### 3.*-1 No more
is @stdout.elems, 0, 'Order: *. No more element in iopub';

# Test history
$cl.wait-history;
is $cl.qa('my $a = "GREP-TEST";'), 'GREP-TEST', 'History Pre';
$cl.wait-shutdown;
await $ke;
($cl, $ke) = spawn-both;
my $hist = $cl.wait-history;
my $last-cmd = $hist<content><history>[*-1][2];
is $last-cmd, 'my $a = "GREP-TEST";', 'History Post';
$cl.wait-shutdown;
await $ke;

## Clean history file
clean-history;

done-testing;
