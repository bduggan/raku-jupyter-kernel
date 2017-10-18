unit class Jupyter::Kernel::Comms;
use Jupyter::Kernel::Comm;
use Log::Async;

# TODO:
#
#    - how do you stop a thread?
#    - tests
#    - look through code
#    - then push (merge?)
#    - then widgets
#    - autocomplete dynamic vars

our %COMM-CALLBACKS;  # keyed on global names
has %.comms;          # keyed on id

method add-comm-callback($name,&callback) {
    %COMM-CALLBACKS{ $name } = &callback;
}

method add-comm(:$id, :$name, :$data) {
    %COMM-CALLBACKS{ $name }:exists or return;
    my &cb = %COMM-CALLBACKS{ $name };
    my $new = Jupyter::Kernel::Comm.new(:$id,:$data,:$name,:&cb);
    $new.run($data);
    %.comms{ $id } = $new;
    return $new;
}

method send-to-comm(:$id,:$data) {
    %.comms{ $id }.run($data);
}
