#= Lexical variable container for completion

unit class Jupyter::Kernel::Handler;
use Jupyter::Kernel::Comms;
use Log::Async;

has SetHash $.lexicals is rw = SetHash.new;
has $.comms handles <comm-ids comm-names>
   = Jupyter::Kernel::Comms.new;
has Array $.imports is rw;


method register-comm($name, &callback --> Nil) {
    $.comms.add-comm-callback($name,&callback);
}


method add-lexicals(@list) {
    info "Adding lexicals: " ~ @list;
    $!lexicals{ |@list }»++;
    info "Hanlder lexicals: " ~ $.lexicals;
}


#| Returns: list of all usable modules
method imports {
    info "Imports lookup is called";
    if $!imports { return $!imports; }

    # Get usaable module list
    info "Imports lookup is working (1 sec)";
    my @module = ($*REPO.repo-chain
        ==> grep(* ~~ CompUnit::Repository::Installable)
        ==> map(*.installed)
        ==> map( *.map(*.meta<provides>.keys ) )
        ==> flat);
    # Prevent empty return
    @module.push('Jupyter::Kernel');

    # Uniq
    $!imports = (@module.unique).Array;
    return $!imports;
}
