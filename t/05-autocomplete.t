#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Log::Async;
use Jupyter::Kernel::Sandbox::Autocomplete;

logger.add-tap(  -> $msg { diag $msg<msg> } );

my $c = Jupyter::Kernel::Sandbox::Autocomplete.new;

ok $c.complete('prin')[2].contains('print'), 'print';
ok $c.complete('(')[2] ⊃ <∩ ∪ ⊂ ⊃>, 'found set ops';
ok $c.complete('( <a b c d>',1)[2] ⊃ <∩ ∪ ⊂ ⊃>, 'found set ops in the middle';
ok $c.complete('(1..10) (')[0,1] eqv (8,9), 'right position';
ok $c.complete('<1 2 3> (')[2] ⊃ <∩ ∪ ⊂ ⊃>, 'found set ops';
ok $c.complete('**')[2] ⊃ <³ ⁴ ⁵ ⁶ ⁷>, 'got some exponents';
is $c.complete('*'), (0, 1, << * × >>), 'multiplication';
is $c.complete('<'), (0, 1, << < ≤ <= >>), 'less than';

{
    my ($pos,$offset,$atomic) = $c.complete('$a atomic','$a atomic'.chars,Nil);
    ok @$atomic > 0, 'got some atomic ops';
    ok <⚛= ⚛> ⊂ $atomic, 'atomic ops contains ⚛= ⚛';
}

{
    my ($pos,$end,$beer) = $c.complete('some :beer','some :beer'.chars,Nil);
    ok @$beer > 0, 'got some beer';
    ok <🍺 🍻> ⊆ $beer, 'beer contains🍺 and 🍻 ';
    is $pos, 5, 'got right start';
    is $end, '10', 'got right end';
}
{
    my ($pos,$end,$beer) = $c.complete('some :b','some :b'.chars,Nil);
    ok $beer.elems ≤ 30, '30 or fewer results';
}
{
    my ($pos,$end,$got) = $c.complete(':less-than',':less-than'.chars,Nil);
    ok '≤' ∈ @$got, 'found less-than';
}
{
    my ($pos,$end,$got) = $c.complete(':less-than-or-equal',':less-than'.chars,Nil);
    ok '≤' ∈ @$got, 'found ≤';
}
{
    my ($pos,$end,$got) = $c.complete('say pi','say pi'.chars,Nil);
    ok 'π' ∈ @$got, 'found π';
}
{
    my ($pos,$end,$got) = $c.complete('pi','pi'.chars,Nil);
    ok 'π' ∈ @$got, 'found π';
}
{
    my ($pos,$end,$got) = $c.complete('tau','tau'.chars,Nil);
    ok 'τ' ∈ @$got, 'found τ';
}
{
    my ($pos,$end,$got) = $c.complete('1..Inf','1..Inf'.chars,Nil);
    ok '∞' ∈ @$got, 'found ∞';
}

done-testing;
# vim: syn=perl6
