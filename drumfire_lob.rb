require "minitest/autorun"

module DrumfireLob
  class IntegrationTest < Minitest::Test
    def test_2_way_branching
      form = Form.new
      # setup
      question1 = Question.new "Are you 18 or more?" # Implying that all questions are boolean ATM
      question2 = Question.new "Fancy some Swiss mulled wine?"
      question3 = Question.new "Fancy some Swiss chocolate?"
      branching = Branching.new(source: question1, yes: questions2, no: question3) # Implying that branching conditions are always yes/no
      
      form << question1
      form << branching
      
      # assert & execute
      form.filling do |f|
        assert_equal "Are you 18 or more?", f.current_question
        
        f.answer :yes
        assert_equal "Fancy some Swiss mulled wine?", f.current_question
        
        f.rollback
        assert_equal "Are you 18 or more?", f.current_question
        
        f.answer :no
        assert_equal "Fancy some Swiss chocolate?", f.current_question
      end
    end
  end
end
