unit class Jupyter::Kernel::Comms;
use Jupyter::Kernel::Comm;
use Log::Async;

our %COMM-CALLBACKS;  # keyed on global names
has %.comms;          # keyed on id
has %.running;

method add-comm-callback($name,&callback) {
    %COMM-CALLBACKS{ $name } = &callback;
}

method add-comm(Str:D :$id, :$name, :$data) {
    %COMM-CALLBACKS{ $name }:exists or return;
    my &cb = %COMM-CALLBACKS{ $name };
    my $new = Jupyter::Kernel::Comm.new(:$id,:$data,:$name,:&cb);
    %.running{ $id } = start $new.run($data);
    %.comms{ $id } = $new;
    return $new;
}

method comm-names {
    %COMM-CALLBACKS.keys;
}

method comm-ids {
    Hash.new( %.comms.map: -> ( :$key, :$value ) { $key => $value.name } )
}

method send-to-comm(:$id,:$data) {
    debug "sending $data to $id";
    %.comms{ $id }.in.send: $data;
}
