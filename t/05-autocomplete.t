#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Log::Async;
use Jupyter::Kernel::Sandbox::Autocomplete;

logger.add-tap(  -> $msg { diag $msg<msg> } );

plan 2;

my $c = Jupyter::Kernel::Sandbox::Autocomplete.new;

my @set-ops = $c.complete-ops('(');

ok @set-ops > 0, 'got some set ops';

my @exp = $c.complete-syntactic('**','');

ok @exp > 0, 'got some superscripts';

# vim: syn=perl6
