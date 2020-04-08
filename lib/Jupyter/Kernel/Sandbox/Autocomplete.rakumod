#= Autocompletion for the sandbox.
unit class Jupyter::Kernel::Sandbox::Autocomplete;
use Log::Async;
use Jupyter::Kernel::Handler;

has $.handler;

method BUILD (:$!handler){
    $!handler = Jupyter::Kernel::Handler.new unless $.handler;
};

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
constant magic-start = ['#% javascript', '#% html', '#% latex', '%% bash', '%% run',
    '%% always', '%% always prepend', '%% always append', '%% always show', '%% always clear'];
constant mop = <WHAT WHO HOW DEFINITE VAR>;

method !find-methods(:$sandbox, Bool :$all, :$var) {
       my $eval-str = $var ~ '.^methods(' ~ (':all' x $all) ~ ').map({.name}).join(" ")';
       my $res = $sandbox.eval($eval-str, :no-persist );
       unless $res and !$res.exception and !$res.incomplete {
           debug 'autocomplete produced an error';
           return ();
       }
       return $res.output-raw.split(' ').unique.Array.append(mop);
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
            }).head(30);
        @chars;
    }
    my $chars = %cache{$word};
    %cache{$word}
}

my sub find-dynamics($str) {
    # Is there a way to get these programmatically?
    # Otherwise:
    #     find src -type f | \
    #     xargs perl -ln -e "/REGISTER-DYNAMIC: '(.*)'.*\$/ and print \$1 =~ s/'.*$//r"
    my @dyns = <ARGFILES COLLATION CWD DEFAULT-READ-ELEMS DISTRO EXECUTABLE EXECUTABLE-NAME
    GROUP HOME INIT-INSTANT INITTIME KERNEL PERL PROGRAM PROGRAM-NAME
    RAKUDO_MODULE_DEBUG REPO THREAD TMPDIR TOLERANCE TZ USER VM JUPYTER>;
    return @dyns.grep: { .fc.starts-with($str.fc) }
}

#| Returns: i_start_repl_pos, i_end_repl_pos, a_possible_repl_strings
method complete($str,$cursor-pos=$str.chars,$sandbox = Nil) {
    my regex identifier { [ \w | '-' | '_' | '::' ]+ }
    my regex sigil { <[&$@%]> | '$*' }
    my regex method-call { <identifier> }
    my regex how-call { '^' <identifier>? }
    my regex invocant {
       | '"' <-["]>+ '"'
       | [ \S+ ]
    }
    my regex uniname { [ \w | '-' ]+ }
    my regex import { [ use | need | require ] }
    my regex pragma-no { 'no' }
    my regex modul { [ \w | '-' | '_' | ':' ]+ }

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
        when /^ '%%' \s+ 'run' \s+ (.*) $/ {
            info "Completion: dir";
            my $path = (~$/[0] || './').IO;
            my $ds = $path.SPEC.dir-sep;
            my $dir = $path.ends-with($ds) ?? $path !! $path.dirname.IO;
            my $found = ($dir.dir ==> map {~$^a ~ ($ds if $^a.d)} ==> grep(/^ $path/) ==> sort);
            return $p - $path.chars, $p, $found;
        }
        when (my $line=$_) and magic-start.any.starts-with($line) {
            info "Completion: magic trigger";
            my $found = magic-start.grep(*.starts-with($line)).map(*~' ').sort;
            return 0, $p, $found;
        }
        when / <invocant> <!after '.'> '.' <!before '.'> <method-call>? $/ {
            info "Completion: method call";
            my @methods = self!find-methods(:$sandbox, var => "$<invocant>", all => so $<method-call>);
            my $meth = ~( $<method-call> // "" );
            my $len = $p - $meth.chars;
            return $len, $p, @methods.grep( { / ^ "$meth" / } ).sort;
        }
        when / <invocant> <!after '.'> '.' <!before '.'> <how-call> $/ {
            info "Completion: method how call";
            my @methods = Metamodel::ClassHOW.^methods(:all).map({"^" ~ .name});
            my $meth = ~( $<method-call> // "" );
            return $p-$<how-call>.chars, $p, @methods.grep({ / ^ "{$<how-call>}" / }).sort;
        }
        when / <import> \s* <modul>? $/ {
            info "Completion: module import";
            my $modul = $<modul> // '';
            my $found = ( grep { / $modul / }, $.handler.imports.Seq).sort.Array;
            return $p - $modul.chars, $p, $found;
        }
        when / <pragma-no> \s* <modul>? $/ {
            info "Completion: pragma no";
            my $modul = $<modul> // '';
            my $found = ( grep { / $modul / }, $.handler.pragmas.Seq).sort.Array;
            return $p - $modul.chars, $p, $found;
        }
        when / ':' <uniname> $/ {
            info "Completion: named parameter";
            my $word = ~ $<uniname>;
            if self!unisearch( $word.fc ) -> @chars {
                my $pos = $str.chars - $word.chars - 1;
                return ( $pos, $pos + $word.chars + 1, @chars );
            }
        }
        when / <sigil> <identifier> $/ {
            info "Completion: lexical variable";
            my $identifier = "$/";
            my $possible = $.handler.lexicals;
            my $found = ( |($possible.keys), |( CORE::.keys ) ).grep( { /^ "$identifier" / } ).sort;
            return $p - $identifier.chars, $p, $found;
        }
        when / '$*' <identifier>? $/ {
            info "Completion: dynamic scalar";
            my $identifier = $<identifier> // '';
            my $found = map { '$*' ~ $_ }, find-dynamics($identifier);
            return $p - $identifier.chars - 2, $p, $found;
        }
        when /<|w> <!after <[$@%&*]>> <identifier> $/ {
            info "Completion: bare word";
            my $last = ~ $<identifier>;
            my %barewords =
                pi => 'π', 'Inf' => '∞', tau => 'τ',
                e => '𝑒', set => '∅', o=> '∘',
                self => 'self', now => 'now', time => 'time', rand => 'rand';
            my @bare;
            @bare.push($_) with %barewords{ $last };
            my $possible = $.handler.lexicals;
            my $found = ( |($possible.keys),
                          |( CORE::.keys ),
                          |($.handler.keywords),
                          |($.handler.loaded),
                        ).grep( { /^ '&'? "$last" / }
                        ).sort.map: { .subst('&', '') }
            @bare.append: @$found if $found;
            return $p - $last.chars, $p, @bare;
        }
        default {
            info "Completion: default";
            my $found = ( |( CORE::.keys ) ).sort;
            return $p, $p, $found;
        }
    }
}
