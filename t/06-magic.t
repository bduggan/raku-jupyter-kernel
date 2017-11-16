#!/usr/bin/env perl6
use lib 'lib';
use Test;
use Log::Async;
use Jupyter::Kernel::Magics;

logger.add-tap( -> $msg { diag $msg<msg> } );

# plan 21;

my $m = Jupyter::Kernel::Magics.new;
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
{
    my $code = q:to/DONE/;
    %% latex
    hello latex
    DONE

    ok my $magic = $m.find-magic($code), 'find-magic recognized %% latex';
    is $code, "hello latex\n", 'find-magic removed magic line';
    ok !$magic.preprocess($code), "preprocess did not return a result";
    is $code, "hello latex\n", 'preprocess removed magic line';
    my $result = $magic.postprocess(:result(MockResult.new));
    is $result.output-mime-type, 'text/latex', 'latex magic set the output mime type';
}
{
    my $code = q:to/DONE/;
    %% latex(equation*)
    hello latex
    DONE

    ok my $magic = $m.find-magic($code), 'find-magic recognized %% latex(equation*)';
    is $code, "hello latex\n", 'find-magic removed magic line';
    ok !$magic.preprocess($code), "preprocess did not return a result";
    is $code, "hello latex\n", 'preprocess removed magic line';
    my $result = $magic.postprocess(:result(MockResult.new(:output<foo>)));
    is $result.output-mime-type, 'text/latex', 'latex magic set the output mime type';
    is $result.output, q:to/LATEX/, 'latex magic enclosed the output';
        \begin{equation*}
        foo
        \end{equation*}
        LATEX
}
{
    my $code = q:to/DONE/;
    %% html
    hello html
    DONE

    ok my $magic = $m.find-magic($code), 'find-magic recognized %% html';
    is $code, "hello html\n", 'find-magic removed magic line';
    ok !$magic.preprocess($code), "preprocess did not return a result";
    is $code, "hello html\n", 'preprocess removed magic line';
    my $result = $magic.postprocess(:result(MockResult.new(:output('hello html<>'))));
    is $result.output-mime-type, 'text/html', 'html magic set the output mime type';
    is $result.output, 'hello html<>', 'html unchanged';
}
{
    my $code = '#% html > html';
    ok my $magic = $m.find-magic($code), 'found magic for mime';
    is $magic.^name, 'Jupyter::Kernel::Magics::Magic::Filters', 'right magic';
    ok !$magic.preprocess($code), 'preprocess does not return true';
    my $result = MockResult.new(:output('going out'),:stdout('going to stdout'));
    ok $result = $magic.postprocess(:$result), 'postprocess returned a result';
    is $result.output-mime-type, 'text/html', 'set output mime type';
    is $result.stdout-mime-type, 'text/html', 'set stdout mime type';
}
{
    my $code = '#% html > latex';
    given $m.find-magic($code)
       .postprocess(:result( MockResult.new(:output<out>,:stdout<std>) )) {
       is .output-mime-type, 'text/html', 'generated html output';
       is .stdout-mime-type, 'text/latex', 'but latex on stdout';
    }
}
{
    my $code = '#% latex > html';
    given $m.find-magic($code)
       .postprocess(:result( MockResult.new(:output<out>,:stdout<std>) )) {
       is .output-mime-type, 'text/latex', 'generated latex output';
       is .stdout-mime-type, 'text/html', 'but html on stdout';
    }
}
{
    my $code = '#% latex(equation) > html';
    given $m.find-magic($code)
       .postprocess(:result( MockResult.new(:output<out>,:stdout<std>) )) {
       is .output-mime-type, 'text/latex', 'generated latex output';
       is .stdout-mime-type, 'text/html', 'but html on stdout';
    }
}
done-testing;

# vim: syn=perl6
