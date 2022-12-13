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

#| Container of always magics registered
my class Always {
    has @.prepend is rw;
    has @.append is rw;
}

#| Globals
my $always = Always.new;

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
class Magic::Filter::Javascript is Magic::Filter {
    has $.mime-type = 'application/javascript';
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
            output => $code,
            output-mime-type => 'application/javascript';
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

class Magic::Always is Magic {
    has Str:D $.subcommand = '';
    has Str:D $.rest = '';

    method preprocess($code! is rw) {
        my $output = '';
        given $.subcommand {
            when 'prepend' { $always.prepend.push($.rest.trim); }
            when 'append' { $always.append.push($.rest.trim); }
            when 'clear' {
                $always = Always.new;
                $output = 'Always actions cleared';
            }
            when 'show' {
                for $always.^attributes -> $attr {
                    $output ~= $attr.name.substr(2)~" = "~$attr.get_value($always).join('; ')~"\n";
                }
            }
        }
        return Result.new:
            output => $output,
            output-mime-type => 'text/plain';
    }
}

class Magic::AlwaysWorker is Magic {
    #= Applyer for always magics on each line
    method unmagicify($code! is rw) {
        my $magic-action = Jupyter::Kernel::Magics.new.parse-magic($code);
        return $magic-action.preprocess($code) if $magic-action;
        return Nil;
    }

    method preprocess($code! is rw) {
        my $pre = ''; my $post = '';
        for $always.prepend -> $magic-code {
            my $container = $magic-code;
            self.unmagicify($container);
            $pre ~= $container ~ ";\n";
        }
        for $always.append -> $magic-code {
            my $container = $magic-code;
            self.unmagicify($container);
            $post ~= ";\n" ~ $container;
        }
        $code = $pre ~ $code ~ $post;
        return Nil;
    }
}

grammar Magic::Grammar {
    rule TOP { <magic> }
    rule magic {
        [ '%%' | '#%' ]
        [ <simple> || <args> || <filter> || <always> ]
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
    token always {
       $<key>='always' <.ws> $<subcommand>=[ '' | 'prepend' | 'append' | 'show' | 'clear' ] $<rest>=.*
    }
    token mime {
       | <html>
       | <latex>
       | <javascript>
    }
    token html {
        'html'
    }
    token javascript {
         'javascript' || 'js'
    }
    token latex {
        'latex' [ '(' $<enclosure>=[ \w | '*' ]+ ')' ]?
    }
}

class Magic::Actions {
    method TOP($/) { $/.make: $<magic>.made }
    method magic($/) {
        $/.make: $<simple>.made // $<filter>.made // $<args>.made // $<always>.made;
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
    method always($/) {
        my $subcommand = ~$<subcommand> || 'prepend';
        my $rest = $<rest> ?? ~$<rest> !! '';
        $/.make: Magic::Always.new(
            subcommand => $subcommand,
            rest => $rest);
    }
    method filter($/) {
        my %args =
            |($<out>    ?? |(out => $<out>.made) !! Empty),
            |($<stdout> ?? |(stdout => $<stdout>.made) !! Empty);
        $/.make: Magic::Filters.new: |%args;
    }
    method mime($/) {
        $/.make: $<html>.made // $<latex>.made // $<javascript>.made;
    }
    method html($/) {
        $/.make: Magic::Filter::HTML.new;
    }
    method javascript($/) {
        $/.make: Magic::Filter::Javascript.new;
    }
    method latex($/) {
        my %args = :enclosure('');
        %args<enclosure> = ~$_ with $<enclosure>;
        $/.make: Magic::Filter::Latex.new(|%args);
    }
}

method parse-magic($code is rw) {
    my $magic-line = $code.lines[0] or return Nil;
    $magic-line ~~ /^ [ '#%' | '%%' ] / or return Nil;
    my $actions = Magic::Actions.new;
    my $match = Magic::Grammar.new.parse($magic-line,:$actions) or return Nil;
    # Parse full cell if always
    if $match<magic><always> {
        $match = Magic::Grammar.new.parse($code,:$actions);
        $code = '';
    # Parse only first line otherwise
    } else {
        $code .= subst( $magic-line, '');
        $code .= subst( /\n/, '');
    }
    return $match.made;
}

method find-magic($code is rw) {
    # Parse
    my $magic-action = self.parse-magic($code);
    # If normal line and there is always magics -> activate them
    if !$magic-action && ($always.prepend || $always.append) {
        return Magic::AlwaysWorker.new;
    }
    return $magic-action;
}
