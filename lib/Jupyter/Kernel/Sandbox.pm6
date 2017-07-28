
use nqp;

%*ENV<RAKUDO_LINE_EDITOR> = 'none';
%*ENV<RAKUDO_DISABLE_MULTILINE> = 0;

my class Result {
    has $.output;
    has $.exception;
    has Bool $.incomplete;
    has $.stdout;
    has $.stderr;
}

class Jupyter::Kernel::Sandbox is export {
    has $.save_ctx;
    has $.compiler;
    has $.repl;

    method TWEAK {
        $!compiler := nqp::getcomp('perl6');
        $!repl = REPL.new($!compiler, {});
    }

    method eval(Str $code) {
        my $stdout;
        my $*CTXSAVE = $!repl;
        my $*MAIN_CTX;
        my $*OUT = class { method print(*@args) { $stdout ~= @args.join }
                           method flush { } }
        my $output = $!repl.repl-eval(
            $code,
            my $exception,
            :outer_ctx($!save_ctx),
            :interactive(1)
        );

        if $*MAIN_CTX {
            $!save_ctx := $*MAIN_CTX;
        }

        $output = ~$exception with $exception;
        my $incomplete = so $!repl.input-incomplete($output);
        return Result.new(:output($output.gist),:$stdout,:$exception, :$incomplete);
    }
}

