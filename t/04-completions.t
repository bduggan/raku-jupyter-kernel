#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Jupyter::Kernel::Sandbox;

unless %*ENV<P6_JUPYTER_TEST_AUTOCOMPLETE> {
    plan :skip-all<Set P6_JUPYTER_TEST_AUTOCOMPLETE to run these>;
}
plan 14;

unless %*ENV<MVM_SPESH_DISABLE> {
    diag "You may need to set MVM_SPESH_DISABLE=1 for these to pass";
}

my $r = Jupyter::Kernel::Sandbox.new;

my ($pos, $end, $completions) = $r.completions('sa', 2);
is-deeply $completions, [<samecase samemark samewith say>], 'completions for "sa"';
is $pos, 0, 'offset';

($pos, $end, $completions) = $r.completions(' sa');
is-deeply $completions, [<samecase samemark samewith say>], 'completions for "sa"';
is $pos, 1, 'offset';

my $res = $r.eval(q[my $x = 'hello'; $x]);
is $res.output, 'hello', 'output';
($pos,$end,$completions) = $r.completions('$x.pe');
is-deeply $completions, <perl perlseen permutations>, 'autocomplete for a string';

$res = $r.eval(q|class Foo { method barglefloober { ... } }; my $y = Foo.new;|);
is $res.output, 'Foo.new', 'declared class';
($pos,$end,$completions) = $r.completions('$y.barglefl');
is-deeply $completions, $( 'barglefloober', ) , 'Declared a class and completion was a method';

$res = $r.eval('my $abc = 12;');
($pos,$end,$completions) = $r.completions('$abc.is-prim');
is-deeply $completions, $('is-prime', ), 'method with a -';

($pos,$end,$completions) = $r.completions('if 15.is-prim');
is-deeply $completions, $( 'is-prime', ), 'is-prime for a number';

($pos,$end,$completions) = $r.completions('if "hello world".sa');
is-deeply $completions, $( 'say', ), 'say for a string';

$res = $r.eval('my $ghostbusters = 99');
is $res.output, 99, 'made a var';
($pos,$end,$completions) = $r.completions('say $ghost');
todo 'autocomplete variables';
is-deeply $completions, $( '$ghostbusters', ), 'completed a variable';

# Generate and error but still get something sane
my $from-here = q[my $d = Flannel.new; $d.ch].chars;
my $str = q[my $d = Flannel.new; $d.ch  and say 'ok'];
($pos,$end,$completions) = $r.completions($str,$from-here);
is $completions, <chars chdir chmod chomp chop chr chrs>, 'got something sane despite error'

# vim: syn=perl6
