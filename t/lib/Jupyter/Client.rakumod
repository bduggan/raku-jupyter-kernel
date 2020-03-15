=begin pod

Small client for test
Very similar to Kernel.pm6

=end pod

unit class Jupyter::Client;

use JSON::Tiny;
use Net::ZMQ4::Constants;
use Jupyter::Kernel::Service;

has Jupyter::Kernel::Service $.ctl is rw;
has Jupyter::Kernel::Service $.shell is rw;
has Jupyter::Kernel::Service $.iopub is rw;
has Jupyter::Kernel::Service $.hb is rw;
has Hash $.spec;

submethod BUILD(:$!spec) {
    sub clt($name, $type, $is-client=True) {
        Jupyter::Kernel::Service.new(
            :$name,
            :url('tcp://127.0.0.1'),
            :socket-type($type),
            :port($!spec{"{ $name }_port"}),
            :key<abcd>,
            :$is-client,
        ).setup;
    }
    $!ctl   = clt('control', ZMQ_DEALER);
    $!shell = clt('shell',   ZMQ_DEALER);
    $!iopub = clt('iopub',   ZMQ_SUB);
    $!hb    = clt('hb',      ZMQ_REP);
    # Subscribe stdstreams to all messages
    $!iopub.socket.setopt(ZMQ_SUBSCRIBE, Blob.new);
    return self;
}

method wait-request (Str(Cool) $request) {
    $.shell.send('execute_request', { :code($request) });
    return $.shell.read-message;
}

method wait-shutdown {
    $.ctl.send('shutdown_request', { :restart(False) });
    return $.ctl.read-message;
}

method wait-history (Str(Cool) $pattern="") {
    $.shell.send('history_request', { :$pattern });
    return $.shell.read-message;
}

method wait-stdio {
    # Call me after a request
    my @res; my %msg;
    repeat {
        %msg = $.iopub.read-message;
        my %topush = %msg;
        @res.push(%topush);
    } until %msg<header><msg_type> eq 'status' and %msg<content><execution_state> eq 'idle';
    return @res;
}

method wait-result {
    # Call me after a request
    my @msg = self.wait-stdio;
    my %result-msg = @msg.grep(*<header><msg_type> eq 'execute_result')[0];
    return %result-msg<content><data><text/plain>
}

method qa (Str(Cool) $request){
    # Question / Answer
    self.wait-request($request);
    return self.wait-result;
}
