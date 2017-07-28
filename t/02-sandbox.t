#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Jupyter::Kernel::Sandbox;

plan 17;

my $r = Jupyter::Kernel::Sandbox.new;

ok defined($r), 'make a new sandbox';

is $r.eval(q["hello"]).output, "hello", 'simple eval';
is $r.eval("12").output, "12", 'stringify';
is $r.eval('my $x = 12; 123;').output, '123', 'made a var';
is $r.eval('$x + 10;').output, "22", 'saved state';

my $res = $r.eval('say "hello"');

ok !$res.incomplete, 'not incomplete';
ok $res.output, 'sent to stdout';
is $res.stdout, "hello\n", 'right value on stdout';

$res = $r.eval('floobody doop');
ok $res.exception, 'caught exception';
like ~$res.exception, /'Undeclared routines'/, 'error message';
like ~$res.exception, /'doop'/, 'error message somewhat useful';
is $res.exception.^name, 'X::Undeclared::Symbols', 'exception type';

$res = $r.eval('for (1..10) {');
ok $res.incomplete, 'identified incomplete input';

$res = $r.eval('my @ints = <1 2 3>;');
ok !$res.exception, 'made an array';
$res = $r.eval('@ints[1]');
is $res.output, "2", 'array';

$res = $r.eval('my @bound := <1 2 3>;');
ok !$res.exception, 'bound an array';
$res = $r.eval('@bound[1]');
is $res.output, "2", 'bound array';

