#= Autocompletion for the sandbox.
unit class Jupyter::Kernel::Sandbox::Autocomplete;
use Log::Async;
use Jupyter::Kernel::Handler;

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

sub add-sigil-or-twigil($prefix is rw, $word) {
   return $word unless $prefix;
   if $prefix.subst-mutate( / $<sigil> = <[$%@&]> $$/, '') {
       return "$<sigil>" ~ $word;
   }
}

method complete($str,$cursor-pos,$sandbox) {
    my $*JUPYTER = CALLERS::<$*JUPYTER> // Jupyter::Kernel::Handler.new;
    my ($prefix,$last) = extract-last-word($str.substr(0,$cursor-pos));
    my $identifier = add-sigil-or-twigil($prefix, $last);

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
       my $all = ':all';
       $all = '' unless $last.chars; # local methods only unless at least 1 char
       my $eval-str = $var ~ '.^methods(' ~ $all ~ ').map({.name}).join(" ")';
       my $res = $sandbox.eval($eval-str, :no-persist );
       if !$res.exception && !$res.incomplete {
           my @methods = $res.output-raw.split(' ').unique;
           return $prefix.chars, $cursor-pos, @methods.grep( { / ^ "$last" / } ).sort;
       }
   }

   # Also handle variables
   if $identifier {
       my $possible = $*JUPYTER.lexicals;
       my $found = ( |($possible.keys), |( CORE::.keys ) ).grep( { /^ "$identifier" / } ).sort;
       return $prefix.chars, $cursor-pos, $found if $found;
   }

   my @possible = CORE::.keys.grep({ /^ '&' / }).map( { .subst(/ ^ '&' /, '') } );
   return $prefix.chars, $cursor-pos, [ @possible.grep( { / ^ "$last" / } ).sort ];
}
