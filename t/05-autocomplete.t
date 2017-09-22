#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Log::Async;
use Jupyter::Kernel::Sandbox::Autocomplete;

logger.add-tap(  -> $msg { diag $msg<msg> } );

plan 4;

my $c = Jupyter::Kernel::Sandbox::Autocomplete.new;

my @set-ops = $c.complete-ops('(');
ok @set-ops > 0, 'got some set ops';

my @exp = $c.complete-syntactic('**','');
ok @exp > 0, 'got some superscripts';

is $c.complete-ops('*'), (0, << * × >>), 'multiplication';
is $c.complete-ops('<'), (0, << < ≤ <= >>), 'less than';

# vim: syn=perl6
