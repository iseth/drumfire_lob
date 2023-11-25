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
        question_or_connector = @form.question_at(@index)
        
        case question_or_connector
        when Question
          question_or_connector.label
        when Branching
          question_or_connector.call(@answers[@index - 1]).label # TODO: better name for `#call`?
        end
      end
      
      def answer(value)
        @answers[@index] = value
        @index = @index + 1
        # FIXME: handle reaching the end of the form 
      end
      
      def rollback
        @index = @index - 1
        @answers.delete_at @index
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
    
    def call(answer)
      case answer
      when :yes
        @yes
      when :no
        @no
      else
        raise ArgumentError, "only :yes and :no are accepted answers, got #{answer}"
      end
    end
  end

  class IntegrationTest < Minitest::Test
    def test_2_way_branching
      # setup
      question3 = Question.new "Fancy some Swiss chocolate?"
      question2 = Question.new "Fancy some Swiss mulled wine?"
      branching = Branching.new(yes: question2, no: question3)             # Implying that branching conditions are always yes/no
      question1 = Question.new "Are you 18 or more?", connector: branching # Implying that all questions are boolean ATM
      
      form = Form.new start: question1
      
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
