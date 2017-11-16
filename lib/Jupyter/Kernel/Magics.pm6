unit class Jupyter::Kernel::Magics;
use Jupyter::Kernel::Response;

my class Result does Jupyter::Kernel::Response {
    has $.output;
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
class Magic::Filter::Plain is Magic::Filter {
    has $.mime-type = 'text/plain';
}

class Magic {
    has Match $.parsed;
    method preprocess($code!) { Nil }
    method postprocess(:$result! ) { $result }
}

my class Magic::JS is Magic {
    method preprocess($code!) {
        return Result.new:
            stdout => $code,
            stdout-mime-type => 'application/javascript';
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
        [ <simple> | <filter> ]
    }
    token simple {
       $<key>='javascript'
    }
    rule filter {
       $<out>=<mime> ['>' $<stdout>=<mime>]?
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
        $/.make: $<simple>.made // $<filter>.made
    }
    method simple($/) {
        $/.make: Magic::JS.new;
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
