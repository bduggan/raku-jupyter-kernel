#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Jupyter::Kernel::Sandbox;
use Jupyter::Kernel::Handler;
use Log::Async;

logger.add-tap( -> $msg { diag $msg<msg> } );

if %*ENV<P6_JUPYTER_TEST_AUTOCOMPLETE> {
    plan 24;
} else {
    plan :skip-all<Set P6_JUPYTER_TEST_AUTOCOMPLETE to run these>;
}

unless %*ENV<MVM_SPESH_DISABLE> {
    diag "You may need to set MVM_SPESH_DISABLE=1 for these to pass";
}

my $iopub_channel = Channel.new;
my $r = Jupyter::Kernel::Sandbox.new(:$iopub_channel);

my ($pos, $end, $completions) = $r.completions('sa', 2);
is-deeply $completions, [ <samecase samemark samewith say> ], 'completions for "sa"';
is $pos, 0, 'offset';

($pos, $end, $completions) = $r.completions(' sa');
is-deeply $completions, [ <samecase samemark samewith say> ], 'completions for "sa"';
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
is-deeply $completions, $("samecase", "samemark", "samespace", "say"), 'string methods';

($pos,$end,$completions) = $r.completions('if "hello world".WHA');
is-deeply $completions, $("WHAT", ), 'WHAT method';

($pos,$end,$completions) = $r.completions('if "hello world".^add_metho');
is-deeply $completions, $("^add_method", ), 'ClassHOW method';

$res = $r.eval('my $ghostbusters = 99', :store);
is $res.output, 99, 'made a var';
($pos,$end,$completions) = $r.completions('say $ghost');
is-deeply $completions, $( '$ghostbusters', ), 'completed a variable';
is $pos, 4, 'position is correct';

# Generate an error but still get something sane
$r.eval('class Flannel { }; my $d = Flannel.new;', :11store); 
my $from-here = q[$d.c].chars;
my $str = q[$d.c  and say 'ok'];
($pos,$end,$completions) = $r.completions($str,$from-here);
is $completions, <cache can categorize classify clone collate combinations>, 'Mu class';

$res = $r.eval(q|sub flubber { 99 };|, :12store );
($pos,$end,$completions) = $r.completions('flubb');
is-deeply $completions, [ <flubber>, ], 'found a subroutine declaration';

{
    my $str = '(1..100).';
    $res = $r.eval(q|(1..100).|, :13store );
    ($pos,$end,$completions) = $r.completions($str);
    ok 'max' ∈ $completions, 'complete an expression';
}
{
    my ($pos,$end,$completions) = $r.completions('wp');
    ok $completions.defined, 'did not get undef';
}
{
    my ($pos,$end,$completions) = $r.completions('2');
    ok $completions.defined, 'did not get undef';
}

# Module
($pos,$end,$completions) = $r.completions('use Log:');
ok 'Log::Async' ∈ $completions, 'module Log::Async';

# Pragma
($pos,$end,$completions) = $r.completions('no st');
ok 'strict' ∈ $completions, 'pragma no strict';

($pos,$end,$completions) = $r.completions('use li');
ok 'lib' ∈ $completions, 'pragma use lib';

done-testing;

# vim: syn=perl6
