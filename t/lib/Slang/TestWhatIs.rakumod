=begin pod

use Slang::TestWhatIs;
say what-is-test;  # OUTPUT: "test is nice"

=end pod

use nqp;
use QAST:from<NQP>;

role TestGrammar {
    token term:sym<what-is-test> { <sym> };
}

role TestActions {
    method term:sym<what-is-test> (Mu $/) {
        return make QAST::SVal.new: :value('test is nice');
    }
}

sub EXPORT(|) {
    $*LANG.refine_slang('MAIN', TestGrammar, TestActions);
    return {};
}
