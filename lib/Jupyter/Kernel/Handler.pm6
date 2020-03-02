#= Lexical variable container for completion

unit class Jupyter::Kernel::Handler;
use Jupyter::Kernel::Comms;
use Log::Async;

has SetHash $.lexicals is rw = SetHash.new;
has $.comms handles <comm-ids comm-names>
   = Jupyter::Kernel::Comms.new;
has Array $.imports is rw;
has Array $.keywords is rw;


method register-comm($name, &callback --> Nil) {
    $.comms.add-comm-callback($name, &callback);
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


# List bare perl6 keywords
# From: https://github.com/Raku/vim-raku/blob/master/syntax/raku.vim
method keywords {
    if $!keywords { return $!keywords; }
    $!keywords = [];
    for (
        # Include
        <use require unit>,
        # Conditional
        <if else elsif unless with orwith without once>,
        # VarStorage
        <let my our state temp has constant>,
        # Repeat
        <for loop repeat while until gather given
        supply react race hyper quietly>,
        # FlowControl
        <take do when next last redo return return-rw
        start default exit make continue break goto leave
        proceed succeed whenever done>,
        # ClosureTrait
        <BEGIN CHECK INIT START FIRST ENTER LEAVE KEEP
        UNDO NEXT LAST PRE POST END CATCH CONTROL TEMP
        DOC QUIT CLOSE COMPOSE>,
        # Exception
        <die fail try warn>,
        # Pragma
        <MONKEY-GUTS MONKEY-SEE-NO-EVAL MONKEY-TYPING MONKEY
        experimental fatal isms lib newline nqp precompilation
        soft strict trace variables worries>,
        # Operator
        <div xx x mod also leg cmp before after eq ne le lt not
        gt ge eqv ff fff and andthen or xor orelse extra lcm gcd o
        unicmp notandthen minmax>,
        # Native Type
        <int int1 int2 int4 int8 int16 int32 int64
        rat rat1 rat2 rat4 rat8 rat16 rat32 rat64
        buf buf1 buf2 buf4 buf8 buf16 buf32 buf64
        uint uint1 uint2 uint4 uint8 uint16 uint32 bit bool
        uint64 utf8 utf16 utf32 bag set mix complex
        num num32 num64 long longlong Pointer size_t str void
        ulong ulonglong ssize_t atomicint>,
        # Types
        <Object Any Junction Whatever Capture Match
        Signature Proxy Matcher Package Module Class
        Grammar Scalar Array Hash KeyHash KeySet KeyBag
        Pair List Seq Range Set Bag Map Mapping Void Undef
        Failure Exception Code Block Routine Sub Macro
        Method Submethod Regex Str Blob Char Byte Parcel
        Codepoint Grapheme StrPos StrLen Version Num
        Complex Bit True False Order Same Less More
        Increasing Decreasing Ordered Callable AnyChar
        Positional Associative Ordering KeyExtractor
        Comparator OrderingPair IO KitchenSink Role
        Int Rat Buf UInt Abstraction Numeric Real
        Nil Mu SeekFromBeginning SeekFromEnd SeekFromCurrent>,
        # Predeclare
        <multi proto only>,
        # Declare
        <macro sub submethod method module class role package enum grammar slang subset>,
        # Type constraint
        <does as but trusts of returns handles where augment supersede>,
        # Property
        # XXX: when prefixed by 'is'
        <signature context also shape prec irs ofs ors export deep
        binary unary reparsed rw parsed cached readonly defequiv will ref copy
        inline tighter looser equiv assoc required DEPRECATED raw repr dynamic
        hidden-from-backtrace nodal pure>,
    ) -> @word {
        $!keywords.push(|@word);
    }
    $!keywords = ($!keywords.sort.squish).Array;
}
