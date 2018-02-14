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
constant atomic-operators = <⚛= ⚛ ++⚛ ⚛++ --⚛ ⚛-- ⚛+= ⚛-= ⚛−=>;

method !find-methods(:$sandbox, Bool :$all, :$var) {
       my $eval-str = $var ~ '.^methods(' ~ (':all' x $all) ~ ').map({.name}).join(" ")';
       my $res = $sandbox.eval($eval-str, :no-persist );
       unless $res and !$res.exception and !$res.incomplete {
           say 'error';
           say $res;
           return;
       }
       $res.output-raw.split(' ').unique;
}

my @CANDIDATES;
my $loading;
unless @CANDIDATES {
    $loading = start @CANDIDATES = (1 .. 0x1ffff).map({.chr})
                      .grep({ not .uniprop.starts-with('C')
                            and not .uniprop.starts-with('Z')
                            and not .uniprop.starts-with('M') });
}

method !unisearch($word) {
  state %cache;
  await $loading;
  %cache{$word} //= do {
    my $alt;
    $alt = $word.subst('-',' ', :global) if $word.contains('-');
    my @chars = @CANDIDATES
        .hyper
        .grep({
            my $u = .uniname.fc;
            $u.contains($word)
            or ($alt and $u.contains(' ') and $u.subst('-',' ', :g).contains($alt))
        }).head(10);
    @chars;
  }
  my $chars = %cache{$word};
  %cache{$word}
}

method complete($str,$cursor-pos=$str.chars,$sandbox = Nil) {
    my $*JUPYTER = CALLERS::<$*JUPYTER> // Jupyter::Kernel::Handler.new;

    my regex identifier { [ \w | '-' | '_' ]+ }
    my regex sigil { <[&$@%]> }
    my regex method-call { [ \w | '-' | '_' ]+ }
    my regex invocant {
       | <sigil>? <identifier>
       | '"' <-["]>+ '"'
    }
    my regex uniname { [ \w | '-' ]+ }

    my $p = $cursor-pos;
    given $str.substr(0,$p) {
        when / [\s|^] '(' $/       { return $p-1, $p, set-operators; }
        when / [\s|^] '='? '=' $/  { return $p-1, $p, equality-operators }
        when / [\s|^] '<' $/       { return $p-1, $p, less-than-operators }
        when / [\s|^] '>' $/       { return $p-1, $p, greater-than-operators }
        when / [\s|^] '*' $/       { return $p-1, $p, << * × >> }
        when / [\s|^] '/' $/       { return $p-1, $p, << / ÷ >> }
        when /  'atomic'  $/       { return $p - 'atomic'.chars, $p, atomic-operators; }
        when / '**' $/             { return $p-2, $p, superscripts }
        when / <[⁰¹²³⁴⁵⁶⁷⁸⁹ⁱ⁺⁻⁼⁽⁾ⁿ]> $/ { return ($p-"$/".chars, $p, [ "$/" X~ superscripts ]); }
        when / <invocant> '.' <method-call>? $/ {
            my @methods = self!find-methods(:$sandbox, var => "$<invocant>", all => so $<method-call>);
            my $len = $p - "$<method-call>".chars;
            my $last = ~ ( $<method-call> // '' );
            return $len, $p, @methods.grep( { / ^ "$last" / } ).sort;
        }
        when / ':' <uniname> $/ {
            my $word = ~ $<uniname>;
            if self!unisearch( $word.fc ) -> @chars {
                my $pos = $str.chars - $word.chars - 1;
                return ( $pos, $pos + $word.chars + 1, @chars );
            }
        }
        when /<|w> <!after <[$@%&]>> <identifier> $/ {
            # subs/barewords
            my $last = ~ $<identifier>;
            my %barewords = pi => 'π', 'Inf' => '∞', tau => 'τ';
            my @bare;
            @bare.push($_) with %barewords{ $last };
            my $possible = $*JUPYTER.lexicals;
            my $found = ( |($possible.keys), |( CORE::.keys )
                        ).grep( { /^ '&'? "$last" / }
                        ).sort.map: { .subst('&','') }
            @bare.append: @$found if $found;
            return $p - $last.chars, $p, @bare if @bare;
        }
        when / <sigil> <identifier> $/ {
            my $identifier = "$/";
            my $possible = $*JUPYTER.lexicals;
            my $found = ( |($possible.keys), |( CORE::.keys ) ).grep( { /^ "$identifier" / } ).sort;
            return $p - $identifier.chars, $p, $found if $found;
        }
        default {
            my $found = ( |( CORE::.keys ) ).sort;
            return $p, $p, $found;
        }
    }
}
