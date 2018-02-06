#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Log::Async;
use Jupyter::Kernel::Sandbox::Autocomplete;

logger.add-tap(  -> $msg { diag $msg<msg> } );

plan 17;

my $c = Jupyter::Kernel::Sandbox::Autocomplete.new;

{
    my ($pos,$ops) = $c.complete-ops('(');
    ok @$ops > 0, 'got some set ops';
    ok <∩ ∪ ⊂ ⊃> ⊂ $ops, 'set ops include ∩ ∪ ⊂ ⊃';
}
{
    my ($pos,$ops) = $c.complete-ops('<1 2 3> (');
    ok @$ops > 0, 'got some set ops';
    ok <∩ ∪ ⊂ ⊃> ⊂ $ops, 'set ops include ∩ ∪ ⊂ ⊃';
}

{
    my ($pos,$offset,$exp) = $c.complete-syntactic('**','');
    ok @$exp > 0, 'got some exponents';
    ok <³ ⁴ ⁵ ⁶ ⁷> ⊂ $exp, 'exponents contain ³ ⁴ ⁵ ⁶ ⁷';
}

is $c.complete-ops('*'), (0, << * × >>), 'multiplication';
is $c.complete-ops('<'), (0, << < ≤ <= >>), 'less than';

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
    ok $beer.elems ≤ 10, '10 or fewer results'; 
}
{
    my ($pos,$end,$got) = $c.complete(':less-than',':less-than'.chars,Nil);
    ok '≤' ∈ @$got, 'found less-than';
}
{
    my ($pos,$end,$got) = $c.complete(':less-than-or-equal',':less-than'.chars,Nil);
    ok '≤' ∈ @$got, 'found ≤';
}



# vim: syn=perl6
