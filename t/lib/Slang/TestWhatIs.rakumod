=begin pod

use Slang::TestWhatIs;
say what-is-test;  # OUTPUT: "test is nice"

=end pod

role TestGrammar {
    token term:sym<what-is-test> { <sym> };
}

role TestActions {
    method term:sym<what-is-test> (Mu $/) {
        return make RakuAST::Literal.from-value('test is nice');
    }
}

use Slangify TestGrammar, TestActions;
