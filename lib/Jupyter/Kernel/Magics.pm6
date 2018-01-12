unit class Jupyter::Kernel::Magics;
use Jupyter::Kernel::Response;

my class Result does Jupyter::Kernel::Response {
    has $.output is default(Nil);
    method output-raw { $.output }
    has $.output-mime-type is rw;
    has $.stdout;
    has $.stdout-mime-type;
    has $.stderr;
    has $.exception;
    has $.incomplete;
    method Bool {
        True;
    }
}

class Magic::Filter {
    method transform($str) {
        # no transformation by default
        $str;
    }
    method mime-type {
        # text/plain by default
        'text/plain';
    }
}
class Magic::Filter::HTML is Magic::Filter {
    has $.mime-type = 'text/html';
}
class Magic::Filter::Latex is Magic::Filter {
    has $.mime-type = 'text/latex';
    has Str $.enclosure;
    method transform($str) {
        if $.enclosure {
            return
                '\begin{' ~ $.enclosure ~ "}\n"
                ~ $str ~ "\n" ~
                '\end{' ~ $.enclosure  ~ "}\n";
        }
        return $str;
    }
}

class Magic {
    method preprocess($code! is rw) { Nil }
    method postprocess(:$result! ) { $result }
}

my class Magic::JS is Magic {
    method preprocess($code!) {
        return Result.new:
            stdout => $code,
            stdout-mime-type => 'application/javascript';
    }
}

my class Magic::Bash is Magic {
    method preprocess($code!) {
        my $cmd = (shell $code, :out, :err);

        return Result.new:
            output => $cmd.out.slurp(:close),
            output-mime-type => 'text/plain',
            stdout => $cmd.err.slurp(:close),
            stdout-mime-type => 'text/plain',
            ;
    }
}

my class Magic::Run is Magic {
    has Str:D $.file is required;
    method preprocess($code! is rw) {
        $.file or return Result.new:
                stdout => "Missing filename to run.",
                stdout-mime-type => 'text/plain';
        $.file.IO.e or
            return Result.new:
                stdout => "Could not find file: {$.file}",
                stdout-mime-type => 'text/plain';
        given $code {
            $_ = $.file.IO.slurp
                ~ ( "\n" x so $_ )
                ~ ( $_ // '')
        }
        return;
    }
}
class Magic::Filters is Magic {
    # Attributes match magic-params in grammar.
    has Magic::Filter $.out;
    has Magic::Filter $.stdout;
    method postprocess(:$result) {
        my $out = $.out;
        my $stdout = $.stdout;
        return $result but role {
            method stdout-mime-type { $stdout.mime-type }
            method output-mime-type { $out.mime-type }
            method output { $out.transform(callsame) }
            method stdout { $stdout.transform(callsame) }
        }
    }
}


grammar Magic::Grammar {
    rule TOP {
        [ '%%' | '#%' ]
        [ <simple> || <args> || <filter> ]
    }
    token simple {
       $<key>=[ 'javascript' | 'bash' ]
    }
    token args {
       $<key>='run' $<rest>=.*
    }
    rule filter {
       [
           | $<out>=<mime> ['>' $<stdout>=<mime>]?
           | '>' $<stdout>=<mime>
       ]
    }
    token mime {
       | <html>
       | <latex>
    }
    token html {
        'html'
    }
    token latex {
        'latex' [ '(' $<enclosure>=[ \w | '*' ]+ ')' ]?
    }
}

class Magic::Actions {
    method TOP($/) {
        $/.make: $<simple>.made // $<filter>.made // $<args>.made
    }
    method simple($/) {
        given "$<key>" {
            when 'javascript' {
                $/.make: Magic::JS.new;
            }
            when 'bash' {
                $/.make: Magic::Bash.new;
            }
        }
    }
    method args($/) {
        given ("$<key>") {
            when 'run' {
                $/.make: Magic::Run.new(file => trim ~$<rest>);
            }
        }
    }
    method filter($/) {
        my %args =
            |($<out>    ?? |(out => $<out>.made) !! Empty),
            |($<stdout> ?? |(stdout => $<stdout>.made) !! Empty);
        $/.make: Magic::Filters.new: |%args;
    }
    method mime($/) {
        $/.make: $<html>.made // $<latex>.made;
    }
    method html($/) {
        $/.make: Magic::Filter::HTML.new;
    }
    method latex($/) {
        my %args = :enclosure('');
        %args<enclosure> = ~$_ with $<enclosure>;
        $/.make: Magic::Filter::Latex.new(|%args);
    }
}

method find-magic($code is rw) {
    my $magic-line = $code.lines[0] or return Nil;
    $magic-line ~~ /^ [ '#%' | '%%' ]/ or return Nil;
    my $actions = Magic::Actions.new;
    my $match = Magic::Grammar.new.parse($magic-line,:$actions) or return Nil;
    $code .= subst( $magic-line, '');
    $code .= subst( /\n/, '');
    return $match.made;
}
