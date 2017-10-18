unit class Jupyter::Kernel::Magics;
use Jupyter::Kernel::Response;

my class Result does Jupyter::Kernel::Response {
    has $.output;
    has $.output-mime-type;
    has $.stdout;
    has $.stdout-mime-type;
    has $.stderr;
    has $.exception;
    has $.incomplete;
    method Bool {
        True;
    }
}

my class Magic::JS {
    has $.keyword = 'javascript';
    method preprocess(:$code!) {
        return Result.new:
            stdout => $code,
            stdout-mime-type => 'application/javascript';
    }
}

our @MAGICS = Magic::JS.new;

method preprocess($code is rw) {
    my regex keyword { 'javascript' }
    my regex magic-line { ^^ [ '#%' | '%%' ] \s* <keyword> "\n"}
    if $code ~~ /^ <magic-line> $<rest>=[.*]$/ {
        my $keyword = ~$<magic-line><keyword>;
        $code = ~$<rest>;
        for @MAGICS -> $class {
            if ~$keyword eq $class.keyword {
                return $_ with $class.preprocess(:$code);
            }
        }
    }
    False;
}

method postprocess($code is rw, $result) {
}
