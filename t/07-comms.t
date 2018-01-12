#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Jupyter::Kernel::Comms;
use Log::Async;
logger.add-tap( -> $msg { diag $msg<msg> } );

plan 11;

my $m = Jupyter::Kernel::Comms.new;
ok $m, 'made comm manager';

$m.add-comm-callback('hello',
    -> :$out, :$data { $out.send: "hello, $data" });
my $c = $m.add-comm(:id<1>, :name<hello>, :data<world>);
ok $c, 'made a comm';
is $c.out.receive, "hello, world", 'received message back from comm';

$m.add-comm-callback('goodbye',
    -> :$out { $out.send: "bye, world" });
my $d = $m.add-comm(:id<2>, :name<goodbye>);
ok $d, 'made a comm';
is $d.out.receive, "bye, world", 'comm with no data';

# Replace
$m.add-comm-callback('hello',
    -> :$out, :$data { $out.send: "hello, $data" });
$c = $m.add-comm(:id<3>, :name<hello>, :data<world>);
ok $c, 'made a comm';
is $c.out.receive, "hello, world", 'received message back from comm';

is $m.comm-names.Set, <hello goodbye>.Set, 'List comms';

is $m.comm-ids.keys.sort, <1 2 3>.sort, '3 ids';

$m.add-comm-callback('howareyou',
    -> :$in, :$out, :$data {
        start {
            my $name = $in.receive;
            $out.send: "hello, $name"
        }
    });
$c = $m.add-comm(:id<3>, :name<howareyou>);
ok $c, 'made a comm';
$c.in.send('bob');
is $c.out.receive, "hello, bob", 'in and out for comm';
