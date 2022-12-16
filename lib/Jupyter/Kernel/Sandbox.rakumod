#!perl6

use Log::Async;
use Jupyter::Kernel::Sandbox::Autocomplete;
use Jupyter::Kernel::Response;
use Jupyter::Kernel::Handler;
use nqp;

%*ENV<RAKUDO_LINE_EDITOR> = 'none';
%*ENV<RAKUDO_DISABLE_MULTILINE> = 0;

state $iopub_supplier;


sub mime-type($str) {
    return do given $str {
        when /:i ^ '<svg' / {
            'image/svg+xml';
        }
        when /:i ^ '<img' / {
            'text/html';
        }
        default { 'text/plain' }
    }
}

my class Result does Jupyter::Kernel::Response {
    has Str $.output;
    has $.output-raw is default(Nil);
    has $.exception;
    has Bool $.incomplete;
    method output-mime-type {
        return mime-type($.output // '');
    }
}

class Std {
    has $.mime-type is rw;

    # Use the channel to be sent all on the same thread
    # For data consistency
    method print(*@args) {
        my $text = @args.join.Str;
        my $mime-type = $.mime-type // mime-type($text);
        if $mime-type eq 'text/plain' {
            $iopub_supplier.emit: ('stream', {:$text, :name(self.stream_name)});
        } else {
            $iopub_supplier.emit: ('display_data', {
                :data( $mime-type => $text ),
                :metadata(Hash.new());
            });
        }
        return True but role { method __hide { True } }
    }
    method say(*@args) {
        self.print(@args.map: * ~ "\n");
    }
    method flush { }
    method stream_name { ... }
}

class Out is Std { method stream_name { 'stdout' } }
class Err is Std { method stream_name { 'stderr' } }

class Jupyter::Kernel::Sandbox is export {
    has $.save_ctx;
    has $.compiler;
    has $.repl;
    has Jupyter::Kernel::Sandbox::Autocomplete $.completer;
    has $.handler;

    method TWEAK (:$!handler, :$iopub_supplier) {
        $!handler = Jupyter::Kernel::Handler.new unless $.handler;
        $OUTERS::iopub_supplier = $iopub_supplier;
        $!compiler := nqp::getcomp("Raku") || nqp::getcomp('perl6');
        $!repl = REPL.new($!compiler, {});
        $!completer = Jupyter::Kernel::Sandbox::Autocomplete.new(:$.handler);
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

    method eval(Str $code, Bool :$no-persist, Int :$store, :$out-mime-type) {
        my $*CTXSAVE = $!repl;
        my $*MAIN_CTX;
        # without setting $PROCESS:: variants, output from Test.pm6
        # is not visible in the notebook.
        $PROCESS::OUT = $*OUT = Out.new(mime-type => $out-mime-type);
        $PROCESS::ERR = $*ERR = Err.new;
        my $exception;
        my $eval-code = $code;
        my $*JUPYTER = $.handler;
        if $store {
            $eval-code = qq:to/DONE/
                my \\_$store = \$(
                    $code
                );
                \$*JUPYTER.set-lang( \$?LANG );
                \$*JUPYTER.add-lexicals( MY::.keys );
                \$Out[$store] := _$store;
                _ = _$store;
                DONE
        }
        if $no-persist {
            # use a temporary package
            $eval-code = qq:to/DONE/;
            my \$out is default(Nil);
            package JupTemp \{
                \$out = $( $code )
            \}
            for (JupTemp::).keys \{
                (JupTemp::)\{\$_\}:delete;
            \}
            \$out;
            DONE
        }

        my $output is default(Nil);
        my $gist;
        try {
            $output = $!repl.repl-eval(
                $eval-code,
                $exception,
                :outer_ctx($!save_ctx),
                :interactive(1)
            );
            $gist = $output.gist;
            $!handler.update-compiler($!compiler);
            CATCH {
                default {
                    $exception = $_;
                }
            }
        }
        given $output {
            $_ = Nil if .?__hide;
            $_ = Nil if try { $_ ~~ List and .elems and .[*-1].?__hide }
            $_ = Nil if $_ === Any;
        }

        if $*MAIN_CTX and !$no-persist {
            $!save_ctx := $*MAIN_CTX;
        }

        with $exception {
            $output = ~$_;
            $gist = $output;
        }
        my $incomplete = so $!repl.input-incomplete($output);
        my $result = Result.new:
            :output($gist),
            :output-raw($output),
            :$exception,
            :$incomplete;

        $result;
    }

    method completions($str, $cursor-pos = $str.chars ) {
        try {
            return self.completer.complete($str,$cursor-pos,self);
            CATCH {
                error "Error completing <$str> at $cursor-pos: " ~ .message;
                return $cursor-pos,$cursor-pos,();
            }
        }
    }
}
