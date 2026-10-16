=begin pod

use Slang::TestWhatIs;
say what-is-test;  # OUTPUT: "test is nice"

=end pod

use experimental :rakuast;
use QAST:from<NQP>;

role TestGrammar {
    token term:sym<what-is-test> { <sym> };
}

role TestActions {
    method term:sym<what-is-test> (Mu $/) {
        return make RakuAST::Literal.from-value('test is nice');
    }
}

role LegacyTestGrammar {
    token term:sym<what-is-test> { <sym> };
}

role LegacyTestActions {
    method term:sym<what-is-test> (Mu $/) {
        return make QAST::SVal.new: :value('test is nice');
    }
}

use Slangify TestGrammar, TestActions, LegacyTestGrammar, LegacyTestActions;
