#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Log::Async;
use Jupyter::Kernel::Magics;

logger.add-tap( -> $msg { diag $msg<msg> } );

plan 9;

my $m = Jupyter::Kernel::Magics.new;

{
    my $code = q:to/DONE/;
        no magic
        DONE
    ok !$m.find-magic($code), 'no magic';
}

{
    my $code = q:to/DONE/;
    %% javascript
    hello world
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% javascript';
    is $code, "hello world\n", 'find-magic removed magic line';
    my $r = $magic.preprocess($code);
    is $r.stdout-mime-type, 'application/javascript', 'js magic set the mime type';
}

class MockResult {
    has $.output;
    has $.output-mime-type;
    has $.stdout;
    has $.stdout-mime-type;
    has $.stderr;
    has $.exception;
    has $.incomplete;
}

{
    my $code = q:to/DONE/;
    %% latex
    hello latex
    DONE

    ok my $magic = $m.find-magic($code), 'preprocess recognized %% latex';
    is $code, "hello latex\n", 'find-magic removed magic line';
    ok !$magic.preprocess($code), "preprocess did not return a result";
    is $code, "hello latex\n", 'preprocess removed magic line';
    my $result = $magic.postprocess(:result(MockResult.new));
    is $result.output-mime-type, 'text/latex', 'latex magic set the output mime type';
}


# vim: syn=perl6
