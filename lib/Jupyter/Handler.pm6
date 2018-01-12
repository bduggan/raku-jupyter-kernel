unit class Jupyter::Handler;
use Jupyter::Kernel::Comms;
use Log::Async;

has SetHash $.lexicals is rw;

method register-comm($name, &callback --> Nil) {
    debug "called register-comm for $name";
    Jupyter::Kernel::Comms.add-comm-callback($name,&callback);
}

method add-lexicals(@list) {
    $!lexicals{ |@list }»++;
}
