#!/usr/bin/env perl6

use lib 'lib';

use Net::ZMQ4::Constants;
use Jupyter::Kernel::Service;
use Log::Async;

use Test;

plan 5;

my $VERBOSE = %*ENV<JUP_VERBOSE>;

my @log;
logger.add-tap: {
    @log.push($_);
    note "# $_<msg>" if $VERBOSE;
};

my $s = Jupyter::Kernel::Service.new:
    :url('tcp://127.0.0.1'),
    :name<test>,
    :port<9099>,
    :key<abcd>,
    :socket-type(ZMQ_ROUTER)
    ;

ok $s.setup, 'setup worked';

my $d = Jupyter::Kernel::Service.new:
    :url('tcp://127.0.0.1'),
    :name<test>,
    :port<9099>,
    :key<abcd>,
    :socket-type(ZMQ_DEALER)
    :is-client,
    ;

ok $d.setup, 'setup worked for dealer';

my $msg = Channel.new;

start loop {
    $msg.send: try $s.read-message;
    note $! if $!;
}

$d.send('other', 'xyzzy');
$d.send('other', 'hello');
is $msg.receive<content>, "xyzzy", 'router-dealer message sent and received';
is $msg.receive<content>, "hello", 'router-dealer message sent and received';

$d.send('other','π');
is $msg.receive<content>, "π", 'router-dealer message sent and received';

# vim: ft=perl6
