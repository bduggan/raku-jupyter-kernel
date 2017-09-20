#= Autocompletion for the sandbox.
unit class Jupyter::Kernel::Sandbox::Autocomplete;
use Log::Async;

constant set-operators = <<
        & ^ | ∈ ∉ ∋ ∌ ∖ ∩ ∪ ⊂ ⊃ ⊄ ⊅ ⊆ ⊇ ⊈ ⊍ ⊎ ⊖ ≼ ≽
        (&) (+) (-) (.) (<) (>) (^) (|)
        (<=) (>=) (>+) (<+)
        (cont) (elem) >>;
constant equality-operators = << ≠ ≅ == != <=> =:= === =~= >>;
constant less-than-operators = << < ≤ <= >>;
constant greater-than-operators = << > ≥ >= >>;
constant superscripts = <⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹ ⁱ ⁺ ⁻ ⁼ ⁽ ⁾ ⁿ>;

method complete-ops($str, $next = '') {
    return unless $str.chars > 0;
    given substr($str,*-1,1) {
        when '(' { return 1, set-operators if $str && $str eq ')';
                   return 0, set-operators;
                 }
        when '=' { return 0, equality-operators }
        when '<' { return 0, less-than-operators }
        when '>' { return 0, greater-than-operators }
        when '*' { return 0, << * × >> }
        when '/' { return 0, << / ÷ >> }
    }
    return;
}

method complete-super($prefix) {
    return unless $prefix;
    if $prefix ~~ /'**'$/ {
        return (2, superscripts);
    }
    return unless $prefix ~~ / <[⁰¹²³⁴⁵⁶⁷⁸⁹ⁱ⁺⁻⁼⁽⁾ⁿ]>+ $ /;
    my $m = "$/";
    return ($m.chars, [ $m X~ superscripts ]);
}

#= Complete based only on the text
method complete-syntactic($prefix, $next = '') {
    with self.complete-ops($prefix, $next) -> $args {
        my ($end,$ops) = @$args;
        return (1, $end, $ops);
    }
    with self.complete-super($prefix) -> $args {
        return ($args[0],0,$args[1])
    }
    return Nil
}

sub extract-last-word(Str $line) {
    # based on src/core/REPL.pm
    my $m = $line ~~ /^ $<prefix>=[.*?] <|w>$<last_word>=[ [\w | '-' | '_' ]* ]$/;
    return ( $line, '') unless $m;
    ( ~$m<prefix>, ~$m<last_word> )
}

method complete($str,$cursor-pos,$sandbox) {
    my ($prefix,$last) = extract-last-word($str.substr(0,$cursor-pos));

    with self.complete-syntactic( $prefix, $str.substr($cursor-pos)) -> $got {
        my ($start, $end, $completions) = @$got;
        return $prefix.chars-$start, $str.chars + $end, $completions;
    }

   # Handle methods.
   if $prefix and $prefix ~~ /'.'$/ {
       my ($pre,$what) = extract-last-word(substr($prefix,0,*-1));
       my $var = $what;
       if $pre ~~ /$<sigil>=<[&$@%]>$/ {
           my $sigil = ~$<sigil>;
           $var = $sigil ~ $what;
       }
       my $res = $sandbox.eval($var ~ '.^methods(:all).map({.name}).join(" ")', :no-persist );
       if !$res.exception && !$res.incomplete {
           my @methods = $res.output-raw.split(' ').unique;
           return $prefix.chars, $cursor-pos, @methods.grep( { / ^ "$last" / } ).sort;
       }
   }

   # Also handle variables
   # TODO: REPL doesn't currently preserve ::.keys in context.
   if $prefix and substr($prefix,*-1,1) eq any('$','%','@','&') {
       my $res = $sandbox.eval('::.keys.join(" ")');
       my @possible = $res.output-raw.split(' ');
       my @found = ( |@possible, |( CORE::.keys ) ).grep( { /^ "$last" / } ).sort;
       return $prefix.chars, $cursor-pos, @found;
   }

   my @completions = $sandbox.repl.completions-for-line($str,$str.chars-1).map({ .subst(/^ "$prefix" /,'') });
   return $prefix.chars, $cursor-pos, @completions;
}
