#!/usr/bin/env perl6

use lib 'lib';

use Net::ZMQ::Constants;
use Jupyter::Kernel::Service;
use Log::Async;

use Test;

plan 3;

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

my $msg;

my $p = start {
    $msg = $s.read-message;
}

$d.send('other', 'xyzzy');

sleep 1;

is $msg<content>, "xyzzy", 'router-dealer message sent and received';

