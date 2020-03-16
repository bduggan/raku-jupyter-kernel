unit class Jupyter::Kernel;

use JSON::Tiny;
use Log::Async;
use Net::ZMQ4::Constants;
use UUID;

use Jupyter::Kernel::Service;
use Jupyter::Kernel::Sandbox;
use Jupyter::Kernel::Magics;
use Jupyter::Kernel::Comms;
use Jupyter::Kernel::History;

has $.engine-id = ~UUID.new: :version(4);
has $.kernel-info = {
    protocol_version => '5.0',
    implementation => 'p6-jupyter-kernel',
    implementation_version => '0.0.12',
    language_info => {
        name => 'raku',
        version => ~$*RAKU.version,
        mimetype => 'text/plain',
        file_extension => '.p6',
    },
    banner => "Welcome to Raku ({ $*RAKU.compiler.name } { $*RAKU.compiler.version }).",
}
has $.magics = Jupyter::Kernel::Magics.new;
has Int $.execution_count = 1;
has $.sandbox;
has $.handler = Jupyter::Kernel::Handler.new;

method resources {
    return %?RESOURCES;
}

method run($spec-file!) {
    info 'starting jupyter kernel';

    my $spec = from-json($spec-file.IO.slurp);
    my $url = "$spec<transport>://$spec<ip>";
    my $key = $spec<key> or die "no key";
    my Jupyter::Kernel::History $history;

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
    my $iopub_channel = Channel.new;

    method ciao (Bool $restart=False) {
        if $restart {
            info "Restarting\n";
            $iopub_channel.send: ('stream', { :text( "The kernel is dead, long live the kernel!\n" ), :name<stdout> });

            # Reset context
            $!handler = Jupyter::Kernel::Handler.new;
            $!sandbox = Jupyter::Kernel::Sandbox.new(:$.handler, :$iopub_channel);
            $!execution_count = 1;

            $ctl.send: 'shutdown_reply', { :$restart }
            self.register-ciao;
            $iopub_channel.send: ('stream', { :text( "Raku kernel restarted\n" ), :name<stdout> });
        } else {
            info "Exiting\n";
            $iopub_channel.send: ('stream', { :text( "Exiting Raku kernel (you may close client)\n" ), :name<stdout> });
            $ctl.send: 'shutdown_reply', { :$restart }
            exit;
        }
    }

    method register-ciao {
        my $*CIAO = sub ($restart=0) { self.ciao(so $restart); }
        my $eval-code = q:to/DONE/;
            my &quit := my &QUIT := my &exit := my &EXIT := $*CIAO;
            42;
        DONE
        my $result = $.sandbox.eval($eval-code);
        $iopub_channel.send: ('execute_input', { :$eval-code, :execution_count(0), :metadata(Hash.new()) });
    }

    start {
        $hb.start-heartbeat;
    }

    # Control
    start loop {
        my $msg = try $ctl.read-message;
        error "error reading data: $!" if $!;
        debug "ctl got a message: { $msg<header><msg_type> // $msg.raku }";
        given $msg<header><msg_type> {
            when 'shutdown_request' {
                self.ciao($msg<content><restart>);
            }
        }
    }

    # Iostream
    start loop {
        my ($tag, %dic) = $iopub_channel.receive;
        $iopub.send: $tag, %dic;
    }

    # Shell
    my $promise = start {
    my $execution_count = 1;
    $!sandbox = Jupyter::Kernel::Sandbox.new(:$.handler, :$iopub_channel);
    self.register-ciao;
    loop {
    try {
        my $msg = $shell.read-message;
        $iopub.parent = $msg;
        debug "shell got a message: { $msg<header><msg_type> }";
        given $msg<header><msg_type> {
            when 'kernel_info_request' {
                $shell.send: 'kernel_info_reply', $.kernel-info;
            }
            when 'execute_request' {
                $iopub_channel.send: ('status', { :execution_state<busy> });
                my $code = ~ $msg<content><code>;
                .append($code,:$!execution_count) with $history;
                my $status = 'ok';
                my $magic = $.magics.find-magic($code);
                my $result;
                $result = .preprocess($code) with $magic;
                $result //= $.sandbox.eval($code, :store($.execution_count));
                if $magic {
                    with $magic.postprocess(:$code,:$result) -> $new-result {
                        $result = $new-result;
                    }
                }
                my %extra;
                $status = 'error' with $result.exception;
                $iopub_channel.send: ('execute_input', { :$code, :$!execution_count, :metadata(Hash.new()) });
                unless $result.output-raw === Nil {
                    $iopub_channel.send: ('execute_result',
                                { :$!execution_count,
                                :data( $result.output-mime-type => $result.output ),
                                :metadata(Hash.new());
                                });
                }
                $iopub_channel.send: ('status', { :execution_state<idle>, });
                my $content = { :$status, |%extra, :$!execution_count,
                       user_variables => {}, payload => [], user_expressions => {} }
                $shell.send: 'execute_reply',
                    $content,
                    :metadata({
                        "dependencies_met" => True,
                        "engine" => $.engine-id,
                        :$status,
                        "started" => ~DateTime.new(now),
                    });
                $!execution_count++;
            }
            when 'is_complete_request' {
                my $code = ~ $msg<content><code>;
                my $status = 'complete';
                if $code.ends-with('\\') {
                  $status = 'incomplete';
                }
                # invalid?
                debug "sending is_complete_reply: $status";
                $shell.send: 'is_complete_reply', { :$status }
            }
            when 'complete_request' {
                my $code = ~$msg<content><code>;
                my Int:D $cursor_pos = $msg<content><cursor_pos>;
                my (Int:D $cursor_start, Int:D $cursor_end, $completions)
                    = $.sandbox.completions($code,$cursor_pos);
                if $completions {
                    $shell.send: 'complete_reply',
                          { matches => $completions,
                            :$cursor_end,
                            :$cursor_start,
                            metadata => {},
                            status => 'ok'
                    }
                } else {
                    $shell.send: 'complete_reply',
                          { :matches([]), :cursor_end($cursor_pos), :0cursor_start, metadata => {}, :status<ok> }
                }
            }
            when 'shutdown_request' {
                self.ciao($msg<content><restart>);
            }
            when 'history_request' {
                $history = Jupyter::Kernel::History.new.init;
                $shell.send: 'history_reply', { :history($history.read) };
            }
            when 'comm_open' {
                my ($comm_id,$data,$name) = $msg<content><comm_id data target_name>;
                with $.handler.comms.add-comm(:id($comm_id), :$data, :$name) {
                    start react whenever .out -> $data {
                        debug "sending a message from $name";
                        $iopub.send: 'comm_msg', { :$comm_id, :$data }
                    }
                } else {
                    $iopub.send( 'comm_close', {} );
                }
            }
            when 'comm_msg' {
                my ($comm_id, $data) = $msg<content><comm_id data>;
                debug "comm_msg for $comm_id";
                $.handler.comms.send-to-comm(:id($comm_id), :$data);
            }
            default {
                warning "unimplemented message type: $_";
            }
        }
        CATCH {
            error "shell: $_";
            error "trace: { .backtrace.list.map: ~* }";
        }
    }}}
    await $promise;
}
