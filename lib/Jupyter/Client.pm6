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
    sub clt($name, $type) {
        Jupyter::Kernel::Service.new(
            :$name,
            :url('tcp://127.0.0.1'),
            :socket-type($type),
            :port($!spec{"{ $name }_port"}),
            :key<abcd>,
            :is-client,
        ).setup;
    }
    $!ctl   = clt('control', ZMQ_DEALER);
    $!shell = clt('shell',   ZMQ_DEALER);
    $!iopub = clt('iopub',   ZMQ_PUB);
    $!hb    = clt('hb',      ZMQ_REP);
    return self;
}


method wait-request(Str $request) {
    $.shell.send('execute_request', { :code($request) });
    return $.shell.read-message;
}

method wait-shutdown {
    $.ctl.send('shutdown_request', { :restart(False) });
    return $.ctl.read-message;
}

method wait-history (Str $pattern="") {
    $.shell.send('history_request', { :$pattern });
    return $.shell.read-message;
}
