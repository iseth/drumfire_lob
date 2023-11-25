require "minitest/autorun"

module DrumfireLob
  class Form
    def initialize
      @questions = []
    end
    
    def <<(question_or_connector)
      @questions << question_or_connector
    end
    
    def filling
     yield Filling.new(self)
    end
    
    def length
      @questions.length
    end
    
    def question_at(index)
      @questions.at index
    end
    
    class Filling
      def initialize form
        @form    = form
        @answers = Array.new(@form.length)
        @index   = 0
      end
      
      def current_question
        @form.question_at(@index).label
      end
    end
  end
  
  class Question
    attr_reader :label
    
    def initialize label
      @label = label
    end
  end
  
  class Branching
    def initialize(source:, yes:, no:)
      @source, @yes, @no = source, yes, no
    end
  end

  class IntegrationTest < Minitest::Test
    def test_2_way_branching
      form = Form.new
      # setup
      question1 = Question.new "Are you 18 or more?" # Implying that all questions are boolean ATM
      question2 = Question.new "Fancy some Swiss mulled wine?"
      question3 = Question.new "Fancy some Swiss chocolate?"
      branching = Branching.new(source: question1, yes: question2, no: question3) # Implying that branching conditions are always yes/no
      
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
