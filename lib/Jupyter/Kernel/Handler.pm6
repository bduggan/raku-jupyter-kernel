#= Lexical variable container for completion

unit class Jupyter::Kernel::Handler;
use Jupyter::Kernel::Comms;
use Log::Async;

has SetHash $.lexicals is rw = SetHash.new;
has $.comms handles <comm-ids comm-names>
   = Jupyter::Kernel::Comms.new;

method register-comm($name, &callback --> Nil) {
    $.comms.add-comm-callback($name,&callback);
}

method add-lexicals(@list) {
    info "Adding lexicals: " ~ @list;
    $!lexicals{ |@list }»++;
    info "Hanlder lexicals: " ~ $.lexicals;
}
