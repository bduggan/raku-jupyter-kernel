#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Jupyter::Kernel::Comms;
use Log::Async;
logger.add-tap( -> $msg { diag $msg<msg> } );

plan 5;

my $m = Jupyter::Kernel::Comms.new;

ok $m, 'made comm manager';

$m.add-comm-callback('hello',
    -> :$channel, :$data { $channel.send: "hello, $data" });
my $c = $m.add-comm(:id<abcd>, :name<hello>, :data<world>);
ok $c, 'made a comm';
is $c.out.receive, "hello, world", 'received message back from comm';

$m.add-comm-callback('goodbye',
    -> :$channel { $channel.send: "bye, world" });
my $d = $m.add-comm(:id<abcd>, :name<goodbye>);
ok $d, 'made a comm';
is $d.out.receive, "bye, world", 'comm with no data';
