#!perl6

use Log::Async;
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

    method TWEAK {
        $!compiler := nqp::getcomp('perl6');
        $!repl = REPL.new($!compiler, {});
    }

    method eval(Str $code, Bool :$no-persist) {
        my $stdout;
        my $*CTXSAVE = $!repl;
        my $*MAIN_CTX;
        my $*OUT = class { method print(*@args) { $stdout ~= @args.join }
                           method flush { } }
        my $exception;
        my $output =
            try $!repl.repl-eval(
                $code,
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

    sub extract-last-word(Str $line) {
        # based on src/core/REPL.pm
        my $m = $line ~~ /^ $<prefix>=[.*?] <|w>$<last_word>=[ [\w | '-' | '_' ]* ]$/;
        return ( $line, '') unless $m;
        ( ~$m<prefix>, ~$m<last_word> )
    }

    #! returns offset and list of completions
    method completions($str) {
        my ($prefix,$last) = extract-last-word($str);

        # Handle methods ourselves.
        if $prefix and substr($prefix,*-1,1) eq '.' {
            my ($pre,$what) = extract-last-word(substr($prefix,0,*-1));
            my $var = $what;
            if $pre ~~ /$<sigil>=<[&$@%]>$/ {
                my $sigil = ~$<sigil>;
                $var = $sigil ~ $what;
            }
            my $res = self.eval($var ~ '.^methods(:all).map({.name}).join(" ")', :no-persist );
            if !$res.exception && !$res.incomplete {
                my @methods = $res.output-raw.split(' ').unique;
                return $prefix.chars, @methods.grep( { / ^ "$last" / } ).sort;
            }
        }

        # Also handle variables
        # TODO: REPL doesn't currently preserve ::.keys in context.
        if $prefix and substr($prefix,*-1,1) eq any('$','%','@','&') {
            my $res = self.eval('::.keys.join(" ")');
            my @possible = $res.output-raw.split(' ');
            my @found = ( |@possible, |( CORE::.keys ) ).grep( { /^ "$last" / } ).sort;
            return $prefix.chars, @found;
        }

        my @completions = $!repl.completions-for-line($str,$str.chars-1).map({ .subst(/^ "$prefix" /,'') });
        return $prefix.chars, @completions;
    }
}

