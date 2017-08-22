unit class Jupyter::Kernel::Service;

use Net::ZMQ;
use Net::ZMQ::Constants;
use Net::ZMQ::Message;
use UUID;
use Log::Async;
use Digest::HMAC;
use Digest::SHA;
use JSON::Tiny;
use NativeCall;

my sub zmq_device(int32, Net::ZMQ::Socket, Net::ZMQ::Socket --> int32)
    is native('zmq',v5) { * }

my $session = ~UUID.new: :version(4);

has $.url is required;
has $.name is required;
has $.socket-type is required;
has $.port is required;
has $.key is required;
has $.ctx;
has $.socket;
has $!session = $session;
has $.is-client = False; # for testing
has $.parent is rw;

method setup {
    debug "setting up $.name on $.port";
    $!ctx = Net::ZMQ::Context.new;
    $!socket = Net::ZMQ::Socket.new( $!ctx, $.socket-type );
    if $!is-client {
        $!socket.connect("$!url:$!port")
    } else {
        $!socket.bind("$!url:$!port")
    }
    self
}

method !hmac(@m) {
    hmac-hex $!key, @m[0] ~ @m[1] ~ @m[2] ~ @m[3], &sha256;
}

method read-message {
    my @identities;
    my @message;
    my $separated = False;
    my $separator = buf8.new: "<IDS|MSG>".encode;
    while $!socket.receive.data() -> $data {
        if !$separated {
            if $data eqv $separator  {
                $separated = True;
                next;
            }
            @identities.push: $data;
            next;
        }
        @message.push: $data;
        last if not $!socket.getopt: ZMQ_RCVMORE;
    }
    error "No message received" unless @message;

    die "HMAC verification failed." if self!hmac(@message[1..4]) ne @message.shift.decode;
    my %msg;
    %msg{$_} = from-json @message.shift.decode for <header parent metadata content>;
    %msg<identities> = @identities;
    %msg<extra_data> = @message;
    $!parent = %msg;
    %msg;
}

method send($type, $message, :$metadata = {} ) {
    info "{ $.name }: sending { $type } message";
    my $identities = $!parent<identities>;

    my $header = {
        date => ~DateTime.new(now),
        msg_id => ~UUID.new(:version(4)),
        msg_type => $type,
        session => $!session,
        username => 'kernel',
        version => '5.0',
    };

    my @parts = (
        $header,
        $!parent<header> // {},
        $metadata,
        $message
    ).map({
       to-json($_)
    });
    my $hmac = self!hmac(@parts);

    for |( @$identities.grep(*.defined) ) {
        my $data = $_;
        my $msg = Net::ZMQ::Message.new(:$data);
        $!socket.send: $msg, ZMQ_SNDMORE;
    }
    my $sep = "<IDS|MSG>";
    for $sep, $hmac, |@parts[0..2] {
        my $data = $_;
        my $msg = Net::ZMQ::Message.new(message => $data);
        $!socket.send: $msg, ZMQ_SNDMORE;
    }
    my $msg = Net::ZMQ::Message.new(message => @parts[3]);
    $!socket.send: $msg;
}

method start-heartbeat {
    loop {
        try zmq_device(ZMQ_FORWARDER, $!socket, $!socket);
        error $! if $!;
        debug 'heartbeat';
        sleep 1;
    }
}
