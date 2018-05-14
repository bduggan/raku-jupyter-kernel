#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Jupyter::Kernel::Sandbox;

plan 50;

my $r = Jupyter::Kernel::Sandbox.new;

ok defined($r), 'make a new sandbox';

is $r.eval(q["hello"]).output, "hello", 'simple eval';
is $r.eval("12").output, "12", 'stringify';
is $r.eval('my $x = 12; 123;').output, '123', 'made a var';
is $r.eval('$x + 10;').output, "22", 'saved state';

my $res = $r.eval('say "hello"');
ok !$res.output-raw, 'no output, sent to stdout';
is $res.stdout, "hello\n", 'right value on stdout';

ok !$res.incomplete, 'not incomplete';
is $res.stdout-mime-type, 'text/plain', 'right mime-type on stdout';

$res = $r.eval('note "goodbye"');
ok !$res.output-raw, 'no output, sent to stderr';
is $res.stderr, "goodbye\n", 'correct value on stderr';

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
is $res.output-mime-type, 'text/plain', 'mime type';

$res = $r.eval('say "<svg></svg>"');
is $res.stdout, "<svg></svg>\n", 'generated svg on stdout';
is $res.stdout-mime-type, 'image/svg+xml', 'svg mime type on stdout';

$res = $r.eval('"<svg></svg>";');
is $res.output, '<svg></svg>', 'generated svg output';
is $res.output-mime-type, 'image/svg+xml', 'svg output mime type';

$res = $r.eval('Int');
is $res.output.perl, '"(Int)"', 'Any works';

$res = $r.eval('die');
is $res.output, 'Died', 'Die trapped';

$res = $r.eval('sub foo { ... }; foo;');
is $res.output, 'Stub code executed', 'trapped sub call that died';

is $r.eval('123', :store(1)).output, "123", 'store eval in Out[1]';
is $r.eval('Out[1]', :store(2)).output, "123", 'get Out[1]';
is $r.eval('_2', :store(3)).output, "123", 'get _2';
is $r.eval('_', :store(4)).output, "123", 'get _';

is $r.eval('my $y = 3; my $x = 99; $x + 1').output, "100", 'two statements';
is $r.eval('my $yy = 3; my $xx = 99; $xx + 1', :store(5)).output, "100", 'two statements';
is $r.eval('_').output, "100", 'saved the right thing';
is $r.eval('_ + 1').output, "101", 'used _ in an expression';

is $r.eval('class Foo { method bar { ... } }', :no-persist).output, '(Foo)', 'class decl';
is $r.eval('class Foo { method bar { ... } }', :no-persist).output, '(Foo)', 'class decl';
is $r.eval('class Foo { method bar { ... } }').output, '(Foo)', 'no-persist a class';

$res = $r.eval(q['hi'; # foo], :store(6));
ok $res, "Produced output when ending with a comment";
is $res.output, "hi", "got right output when ending with a comment";

ok 1, 'still here';

ok $r.eval('Any').output-raw === Nil, "Any becomes Nil";
ok $r.eval('Nil').output-raw === Nil, "Nil becomes Nil";
ok $r.eval('say 12').output-raw === Nil, "say becomes Nil";
is $r.eval('my Int $x;').output, "(Int)", "Output from a type (undefined)";

my $result = $r.eval('.say for 1..10', :store(7));
ok $result.output-raw === Nil, "No output for multiple say's";
is $result.stdout, (1..10).join("\n") ~ "\n", "right stdout for multiple say's";

$res = $r.eval('1/0');
ok $res, 'survived exception';
like $res.output, /:i 'attempt to divide' .* 'by zero' /, 'trapped 1/0 error';

