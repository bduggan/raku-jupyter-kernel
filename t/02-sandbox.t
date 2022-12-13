#!/usr/bin/env perl6

use lib 'lib';
use lib 't/lib';

use Test;
use Jupyter::Kernel::Sandbox;
use Log::Async;

plan 54;

my $VERBOSE = %*ENV<JUP_VERBOSE>;
my @log;
logger.add-tap: {
    @log.push($_);
    note "# $_<msg>" if $VERBOSE;
};


my $iopub_supplier = Supplier.new;
my $sandbox = Jupyter::Kernel::Sandbox.new(:$iopub_supplier);
my $iopub_channel = $iopub_supplier.Supply.Channel;
ok defined($sandbox), 'make a new sandbox';

sub stream {
    my (@out, @err, @out-mime);
    while my $msg = $iopub_channel.poll {
        if $msg[0] eq 'display_data' {
            @out.push($msg[1]<data>.values[0]);
            @out-mime.push($msg[1]<data>.keys[0]);
        }
        next unless $msg[0] eq 'stream';
        if $msg[1]<name> eq 'stdout' {
            @out.push($msg[1]<text>);
        } elsif $msg[1]<name> eq 'stderr' {
            @err.push($msg[1]<text>);
        }
    }
    return {:@out, :@err, :@out-mime}
}

sub qa (Str $code, Bool :$no-persist, Int :$store){
    return {res => $sandbox.eval($code, :$no-persist, :$store), std=>stream};
}

my ($a, $res);

is qa(q["hello"])<res>.output, "hello", 'simple eval';
is qa("12")<res>.output, "12", 'stringify';
is qa('my $x = 12; 123;')<res>.output, '123', 'made a var';
is qa('$x + 10;')<res>.output, "22", 'saved state';

$a = qa('say "hello"');
ok !$a<res>.output-raw, 'no output, sent to stdout';
is $a<std><out>[0], "hello\n", 'right value on stdout';

ok !$a<res>.incomplete, 'not incomplete';
is $a<res>.output-mime-type, 'text/plain', 'right mime-type on stdout';

$a = qa('note "goodbye"');
ok !$a<res>.output-raw, 'no output, sent to stderr';
is $a<std><err>[0], "goodbye\n", 'correct value on stderr';

$res = qa('floobody doop')<res>;
ok $res.exception, 'caught exception';
like ~$res.exception, /'Undeclared routines'/, 'error message';
like ~$res.exception, /'doop'/, 'error message somewhat useful';
is $res.exception.^name, 'X::Undeclared::Symbols', 'exception type';

$res = qa('for (1..10) {')<res>;
ok $res.incomplete, 'identified incomplete input';

$res = qa('my @ints = <1 2 3>;')<res>;
ok !$res.exception, 'made an array';
$res = qa('@ints[1]')<res>;
is $res.output, "2", 'array';

$res = qa('my @bound := <1 2 3>;')<res>;
ok !$res.exception, 'bound an array';
$res = qa('@bound[1]')<res>;
is $res.output, "2", 'bound array';
is $res.output-mime-type, 'text/plain', 'mime type';

$a = qa('say "<svg></svg>"');
is $a<std><out>[0], "<svg></svg>\n", 'generated svg on stdout';
is $a<std><out-mime>[0], "image/svg+xml", 'svg mime type on stdout';

$res = qa('"<svg></svg>";')<res>;
is $res.output, '<svg></svg>', 'generated svg output';
is $res.output-mime-type, 'image/svg+xml', 'svg output mime type';

$res = qa('Int')<res>;
is $res.output.perl, '"(Int)"', 'Any works';

$res = qa('die')<res>;
is $res.output, 'Died', 'Die trapped';

$res = qa('sub foo { ... }; foo;')<res>;
is $res.output, 'Stub code executed', 'trapped sub call that died';

is qa('123', :store(1))<res>.output, "123", 'store eval in Out[1]';
is qa('Out[1]', :store(2))<res>.output, "123", 'get Out[1]';
is qa('_2', :store(3))<res>.output, "123", 'get _2';
is qa('_', :store(4))<res>.output, "123", 'get _';

is qa('my $y = 3; my $x = 99; $x + 1')<res>.output, "100", 'two statements';
is qa('my $yy = 3; my $xx = 99; $xx + 1', :store(5))<res>.output, "100", 'two statements';
is qa('_')<res>.output, "100", 'saved the right thing';
is qa('_ + 1')<res>.output, "101", 'used _ in an expression';

is qa('class Foo { method bar { ... } }', :no-persist)<res>.output, '(Foo)', 'class decl';
is qa('class Foo { method bar { ... } }', :no-persist)<res>.output, '(Foo)', 'class decl';
is qa('class Foo { method bar { ... } }')<res>.output, '(Foo)', 'no-persist a class';

$res = qa(q['hi'; # foo], :store(6))<res>;
ok $res, "Produced output when ending with a comment";
is $res.output, "hi", "got right output when ending with a comment";

ok 1, 'still here';

ok qa('Any')<res>.output-raw === Nil, "Any becomes Nil";
ok qa('Nil')<res>.output-raw === Nil, "Nil becomes Nil";
ok qa('say 12')<res>.output-raw === Nil, "say becomes Nil";
is qa('my Int $x;')<res>.output, "(Int)", "Output from a type (undefined)";

$a = qa('.say for 1..10', :store(7));
ok $a<res>.output-raw === Nil, "No output for multiple say's";
is $a<std><out>.join, (1..10).join("\n") ~ "\n", "right stdout for multiple say's";

$res = qa('1/0')<res>;
ok $res, 'survived exception';
like $res.output, /:i 'attempt to divide' .* 'by zero' /, 'trapped 1/0 error';

# Operator overload persistence
is qa('sub infix:<test-op>($a, $b){return ">" ~ $a ~ ":" ~ $b ~ "<"}; "to" test-op "ti";', :store(1))<res>.output, '>to:ti<', 'Operator: test-op';
is qa('12 test-op 13 test-op 14')<res>.output, '>>12:13<:14<', 'Operator: test-op';

# Slang persistence
is qa('use Slang::TestWhatIs; what-is-test', :store(1))<res>.output, 'test is nice', 'Slang: use';
is qa('what-is-test', :store(1))<res>.output, 'test is nice', 'Slang: persistance';
