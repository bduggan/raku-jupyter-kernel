#!perl6

use Log::Async;
use Jupyter::Kernel::Sandbox::Autocomplete;
use nqp;

%*ENV<RAKUDO_LINE_EDITOR> = 'none';
%*ENV<RAKUDO_DISABLE_MULTILINE> = 0;

my class Result {
    has Str $.output;
    has $.output-raw;
    has $.exception;
    has Bool $.incomplete;
    has $.stdout;
    has $.stderr;
    method !mime-type($str) {
        return do given $str {
            when /:i ^ '<svg' / {
                'image/svg+xml';
            }
            default { 'text/plain' }
        }
    }
    method stdout-mime-type {
        return self!mime-type($.stdout);
    }
    method output-mime-type {
        return self!mime-type($.output);
    }
}

class Jupyter::Kernel::Sandbox is export {
    has $.save_ctx;
    has $.compiler;
    has $.repl;
    has $.completer = Jupyter::Kernel::Sandbox::Autocomplete.new;

    method TWEAK {
        $!compiler := nqp::getcomp('perl6');
        $!repl = REPL.new($!compiler, {});
        self.eval(q:to/INIT/);
            my $Out = [];
            sub Out { $Out };
            my \_ = do {
                state $last;
                Proxy.new( FETCH => method () { $last },
                           STORE => method ($x) { $last = $x } );
            }
        INIT
    }

    method eval(Str $code, Bool :$no-persist, Int :$store) {
        my $stdout;
        my $*CTXSAVE = $!repl;
        my $*MAIN_CTX;
        my $*OUT = class { method print(*@args) { $stdout ~= @args.join }
                           method flush { } }
        my $exception;
        my $eval-code = $code;
        if $store {
            $eval-code = qq:to/DONE/
                my \\_$store = \$( $code );
                \$Out[$store] := _$store;
                _ = _$store;
                DONE
        }
        my $output =
            try $!repl.repl-eval(
                $eval-code,
                $exception,
                :outer_ctx($!save_ctx),
                :interactive(1)
            );
        my $caught;
        $caught = $! if $!;

        if $*MAIN_CTX and !$no-persist {
            $!save_ctx := $*MAIN_CTX;
        }

        $output = ~$_ with $exception // $caught;
        my $incomplete = so $!repl.input-incomplete($output);
        return Result.new(:output($output.gist),:output-raw($output),:$stdout,:$exception, :$incomplete);
    }

    method completions($str, $cursor-pos = $str.chars ) {
        return self.completer.complete($str,$cursor-pos,self);
    }
}

