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

role Magic {
    method keyword { ... }
    #| May return a Result.
    method preprocess($code!) { ... }
    method postprocess(:$result!) { ... }
    method applies(:$magic-line, :$keyword) {
        return self if $keyword eq self.keyword;
        return Nil;
    }
}

my class Magic::JS does Magic {
    has $.keyword = 'javascript';
    method preprocess($code!) {
        return Result.new:
            stdout => $code,
            stdout-mime-type => 'application/javascript';
    }
    method postprocess(:$result!) { }
}

my class Magic::Latex does Magic {
    has $.keyword = 'latex';
    method preprocess($code!) { }
    method postprocess(:$result!) {
        return Result.new:
            stdout => $result.stdout,
            stdout-mime-type => $result.stdout-mime-type,
            output => $result.output,
            output-mime-type => 'text/latex',
            stderr => $result.stderr,
            exception => $result.exception,
            incomplete => $result.incomplete;
    }
}

our @MAGICS = (
    Magic::JS.new,
    Magic::Latex.new,
);

method find-magic($code is rw) {
    my regex keyword { \w+ }
    my regex magic-line { ^^ [ '#%' | '%%' ] \s* <keyword> "\n"}
    my ( $keyword, $magic-line );
    $code ~~ /^ <magic-line> $<rest>=[.*]$/ or return Nil;
    $keyword = ~$<magic-line><keyword>;
    $magic-line = ~$<magic-line>;
    $code = ~$<rest>;
    return @MAGICS.first( *.applies(:$magic-line,:$keyword) );
}
