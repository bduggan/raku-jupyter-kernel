#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Jupyter::Kernel::Sandbox;

unless %*ENV<P6_JUPYTER_TEST_AUTOCOMPLETE> {
    plan :skip-all<Set P6_JUPYTER_TEST_AUTOCOMPLETE to run these>;
}
plan 13;

my $r = Jupyter::Kernel::Sandbox.new;

my ($pos, $completions) = $r.completions('sa');
is-deeply $completions, [<samecase samemark samewith say>], 'completions for "sa"';
is $pos, 0, 'offset';

($pos, $completions) = $r.completions(' sa');
is-deeply $completions, [<samecase samemark samewith say>], 'completions for "sa"';
is $pos, 1, 'offset';

my $res = $r.eval(q[my $x = 'hello'; $x]);
is $res.output, 'hello', 'output';
($pos,$completions) = $r.completions('$x.pe');
is-deeply $completions, <perl perlseen permutations>, 'autocomplete for a string';

$res = $r.eval(q|class Foo { method barglefloober { ... } }; my $y = Foo.new;|);
is $res.output, 'Foo.new', 'declared class';
($pos,$completions) = $r.completions('$y.barglefl');
is-deeply $completions, $( 'barglefloober', ) , 'Declared a class and completion was a method';

$res = $r.eval('my $abc = 12;');
($pos,$completions) = $r.completions('$abc.is-prim');
is-deeply $completions, $('is-prime', ), 'method with a -';

($pos,$completions) = $r.completions('if 15.is-prim');
is-deeply $completions, $( 'is-prime', ), 'is-prime for a number';

($pos,$completions) = $r.completions('if "hello world".sa');
is-deeply $completions, $( 'say', ), 'say for a string';

$res = $r.eval('my $ghostbusters = 99');
is $res.output, 99, 'made a var';
($pos,$completions) = $r.completions('say $ghost');
todo 'autocomplete variables';
is-deeply $completions, $( '$ghostbusters', ), 'completed a variable';

