#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Log::Async;
use Jupyter::Kernel::Magics;

logger.add-tap( -> $msg { diag $msg<msg> } );

plan 7;

my $m = Jupyter::Kernel::Magics.new;

{
    my $code = q:to/DONE/;
        no magic
        DONE
    ok !$m.preprocess($code), 'preprocess recognized no magic';
}

{
    my $code = q:to/DONE/;
    %% javascript
    hello world
    DONE

    ok my $r = $m.preprocess($code), 'preprocess recognized %% javascript';
    is $code, "hello world\n", 'preprocess removed magic line';
    is $r.stdout-mime-type, 'application/javascript', 'js magic set the mime type';
}
{
    my $code = q:to/DONE/;
    #% javascript
    hello world
    DONE

    ok my $r = $m.preprocess($code), 'preprocess recognized #% javascript';
    is $code, "hello world\n", 'preprocess removed magic line for #%';
    is $r.stdout-mime-type, 'application/javascript', 'js magic set the mime type for #%';
}



# vim: syn=perl6
