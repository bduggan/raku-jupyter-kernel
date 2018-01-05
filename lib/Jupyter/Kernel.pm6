
unit class Jupyter::Kernel;

use JSON::Tiny;
use Log::Async;
use Net::ZMQ4::Constants;
use UUID;

use Jupyter::Kernel::Service;
use Jupyter::Kernel::Sandbox;
use Jupyter::Kernel::Magics;

has $.engine-id = ~UUID.new: :version(4);
has $.kernel-info = {
    protocol_version => '5.0',
    implementation => 'p6-jupyter-kernel',
    implementation_version => '0.0.6',
    language_info => {
        name => 'perl6',
        version => ~$*PERL.version,
        mimetype => 'text/plain',
        file_extension => '.p6',
    },
    banner => "Welcome to Perl 6 ({ $*PERL.compiler.name } { $*PERL.compiler.version }).",
}
has $.magics = Jupyter::Kernel::Magics.new;

method resources {
    return %?RESOURCES;
}

method run($spec-file!) {
    info 'starting jupyter kernel';

    my $spec = from-json($spec-file.IO.slurp);
    my $url = "$spec<transport>://$spec<ip>";
    my $key = $spec<key> or die "no key";
    debug "read $spec-file";
    debug "listening on $url";

    sub svc($name, $type) {
        Jupyter::Kernel::Service.new( :$name, :socket-type($type),
                :port($spec{"{ $name }_port"}), :$key, :$url).setup;
    }

    my $ctl   = svc('control', ZMQ_ROUTER);
    my $shell = svc('shell',   ZMQ_ROUTER);
    my $iopub = svc('iopub',   ZMQ_PUB);
    my $hb    = svc('hb',      ZMQ_REP);

    start {
        $hb.start-heartbeat;
    }

    # Control
    start loop {
        my $msg = try $ctl.read-message;
        error "error reading data: $!" if $!;
        debug "ctl got a message: { $msg<header><msg_type> // $msg.perl }";
    }

    # Shell
    my $execution_count = 1;
    my $sandbox = Jupyter::Kernel::Sandbox.new;
    my $promise = start loop {
    try {
        my $msg = $shell.read-message;
        $iopub.parent = $msg;
        debug "shell got a message: { $msg<header><msg_type> }";
        given $msg<header><msg_type> {
            when 'kernel_info_request' {
                $shell.send: 'kernel_info_reply', $.kernel-info;
            }
            when 'execute_request' {
                $iopub.send: 'status', { :execution_state<busy> }
                my $code = ~ $msg<content><code>;
                my $status = 'ok';
                my $magic = $.magics.find-magic($code);
                my $result;
                $result = .preprocess($code) with $magic;
                $result //= $sandbox.eval($code, :store($execution_count));
                if $magic {
                    with $magic.postprocess(:$code,:$result) -> $new-result {
                        $result = $new-result;
                    }
                }
                my %extra;
                $status = 'error' with $result.exception;
                $iopub.send: 'execute_input', { :$code, :$execution_count, :metadata(Hash.new()) };
                if defined( $result.stdout ) {
                    if $result.stdout-mime-type eq 'text/plain' {
                        $iopub.send: 'stream', { :text( $result.stdout ), :name<stdout> };
                    } else {
                        $iopub.send: 'display_data', {
                            :data( $result.stdout-mime-type => $result.stdout );
                        }
                    }
                }
                unless $result.output-raw === Nil {
                    $iopub.send: 'execute_result',
                                { :$execution_count,
                                :data( $result.output-mime-type => $result.output ),
                                }
                }
                $iopub.send: 'status', { :execution_state<idle>, }
                my $content = { :$status, |%extra, :$execution_count,
                       user_variables => {}, payload => [], user_expressions => {} };
                $shell.send: 'execute_reply',
                    $content,
                    :metadata({
                        "dependencies_met" => True,
                        "engine" => $.engine-id,
                        :$status,
                        "started" => ~DateTime.new(now),
                    });
                $execution_count++;
            }
            when 'is_complete_request' {
                my $code = ~ $msg<content><code>;
                my $result = $sandbox.eval($code, :no-persist);
                my $status = 'complete';
                debug "exception from sandbox: { .gist }" with $result.exception;
                $status = 'invalid' if $result.exception;
                $status = 'incomplete' if $result.incomplete;
                debug "sending is_complete_reply: $status";
                $shell.send: 'is_complete_reply', { :$status };
            }
            when 'complete_request' {
                my $code = ~$msg<content><code>;
                my $cursor_pos = $msg<content><cursor_pos>;
                my (Int $cursor_start, Int $cursor_end, $completions)
                    = $sandbox.completions($code,$cursor_pos);
                $completions //= [];
                $shell.send: 'complete_reply',
                      { matches => $completions,
                        :$cursor_end,
                        :$cursor_start,
                        metadata => {},
                        status => 'ok'
                }
            }
            when 'shutdown_request' {
                my $restart = $msg<content><restart>;
                $restart = False;
                $shell.send: 'shutdown_reply', { :$restart };
                exit;
            }
            when 'history_request' {
                # > Most of the history messaging options are not used by
                # > Jupyter frontends, and many kernels do not implement them.
                # > The notebook interface does not use history messages at all.
                # − http://jupyter-client.readthedocs.io/en/latest/messaging.html#history
            }
            default {
                warning "unimplemented message type: $_";
            }
        }
        CATCH {
            error "shell: $_";
            error "trace: { .backtrace.list.map: ~* }";
        }
    }
    }
    await $promise;
}
