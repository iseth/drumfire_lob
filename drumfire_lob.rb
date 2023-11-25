require "minitest/autorun"

module DrumfireLob
  class Form
    attr_reader :start
    
    def self.collect_questions(question, memo = {})
      memo.store question.object_id, question
      question.follow_ups.each { |q| collect_questions q, memo }
      memo
    end
    
    def initialize(start:)
      @start = start
      @questions = Form.collect_questions(@start)
    end
    
    def filling
     yield Filling.new(self)
    end
    
    def find_question(id)
      @questions.fetch id
    end
    
    class Filling
      attr_reader :current_question
      
      def initialize form
        @form    = form
        @answers = {}
        @current_question = @form.start
      end
      
      def answer(value)
        @answers.store current_question.object_id, value
        
        @current_question = @current_question.connector.(value) # TODO: better name for `#call`?
        # FIXME: handle reaching the end of the form 
      end
      
      def rollback
        @answers.delete @current_question.object_id
        @current_question = @form.find_question(@answers.keys.last) # FIXME: seems very brittle
      end
    end
  end
  
  class Question
    attr_reader :label, :connector
    
    def initialize label, connector: NullConnector.new
      @label, @connector = label, connector
    end
    
    def follow_ups # TODO: better name maybe?
      connector.questions
    end
  end
  
  class Branching
    def initialize(yes:, no:)
      @yes, @no = yes, no
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
    
    def questions
      [@yes, @no]
    end
  end
  
  class NullConnector
    def call(*)
      # noop
    end
    
    def questions
      []
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
      submission = form.filling do |f|
        assert_equal "Are you 18 or more?", f.current_question.label
        
        f.answer :yes
        assert_equal "Fancy some Swiss mulled wine?", f.current_question.label
        
        f.rollback
        assert_equal "Are you 18 or more?", f.current_question.label
        
        f.answer :no
        assert_equal "Fancy some Swiss chocolate?", f.current_question.label
        
        f.answer :yes
      end
      
      assert_output(<<~TXT) { submission.print_out }
        - Are you 18 or more?
          > No
        - Fancy some Swiss chocolate?
          > Yes
      TXT
    end
  end
end
