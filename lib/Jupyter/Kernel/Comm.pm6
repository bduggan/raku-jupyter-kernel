unit class Jupyter::Kernel::Comm;
use Log::Async;

has $.id;
has $.data;
has $.name;
has Channel $.out .= new;
has &.cb is required;

method run($data) {
    my %args;
    my $params = &.cb.signature.params;
    if $params.grep: *.name eq '$channel' {
        %args<channel> = $.out;
    }
    if $params.grep: *.name eq '$data' {
        %args<data> = $data;
    }
    &.cb()(|%args);
}
