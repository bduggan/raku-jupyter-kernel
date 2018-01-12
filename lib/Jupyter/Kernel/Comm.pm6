unit class Jupyter::Kernel::Comm;
use Log::Async;

has $.id;
has $.data;
has $.name;
has Channel $.out .= new;
has Channel $.in .= new;
has &.cb is required;

method run($data) {
    my %args;
    given &.cb.signature.params {
        %args<out>  = $.out if .grep: *.name eq '$out';
        %args<in>   = $.in  if .grep: *.name eq '$in';
        %args<data> = $data if .grep: *.name eq '$data';
    }
    &.cb()(|%args);
}

