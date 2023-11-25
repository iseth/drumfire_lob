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
      Filling.new(self).tap { yield _1 }
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
      
      def ended?
        @current_question.nil?
      end
      
      def print_out
        @answers.each do |question_id, answer|
          puts "- #{@form.find_question(question_id).label}"
          puts "  > #{answer.capitalize}"
        end
      end
    end
  end
  
  class Question
    attr_reader :label, :connector
    
    def initialize label, choices: %i(yes no), connector: NullConnector.new
      @label, @choices, @connector = label, choices, connector
    end
    
    def follow_ups # TODO: better name maybe?
      connector.questions.compact
    end
  end
  
  class Branching
    def initialize(**branches)
      @branches = branches
    end
    
    def call(answer)
      begin
        @branches.fetch answer
      rescue KeyError
        raise ArgumentError, "only #{accepted_values} are accepted answers, got #{answer}"
      end
    end
    
    def questions
      @branches.values
    end
    
    def accepted_values
      @branches.keys[..-2].map(&:to_s).join(", ") + " or " + @branches.keys.last.to_s
    end
  end
  
  class ComparisonBranching < Branching
    def call(answer)
      
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

  module IntegrationTests
    class TwoWayBranchingTest < Minitest::Test
      def setup
        question4 = Question.new "Awesome! Do you prefer dark chocolate or milk chocolate?", choices: %i(dark milk)
        question3 = Question.new "Fancy some Swiss chocolate?", connector: Branching.new(yes: question4, no: nil)
        question2 = Question.new "Fancy some Swiss mulled wine?"
        branching = Branching.new(yes: question2, no: question3)
        question1 = Question.new "Are you 18 or more?", connector: branching
        
        @form = Form.new start: question1
      end
      
      def test_2_way_branching_short
        submission = @form.filling do |f|
          assert_equal "Are you 18 or more?", f.current_question.label
          
          f.answer :yes
          assert_equal "Fancy some Swiss mulled wine?", f.current_question.label
          
          f.answer :no
          
          assert f.ended?
        end
        
        assert_output(<<~TXT) { submission.print_out }
          - Are you 18 or more?
            > Yes
          - Fancy some Swiss mulled wine?
            > No
        TXT
      end
      
      def test_2_way_branching_medium
        submission = @form.filling do |f|
          assert_equal "Are you 18 or more?", f.current_question.label
          
          f.answer :no
          assert_equal "Fancy some Swiss chocolate?", f.current_question.label
          
          f.answer :no
          
          assert f.ended?
        end
        
        assert_output(<<~TXT) { submission.print_out }
          - Are you 18 or more?
            > No
          - Fancy some Swiss chocolate?
            > No
        TXT
      end
      
      def test_2_way_branching_long_with_rollback
        # assert & execute
        submission = @form.filling do |f|
          assert_equal "Are you 18 or more?", f.current_question.label
          
          f.answer :yes
          assert_equal "Fancy some Swiss mulled wine?", f.current_question.label
          
          f.rollback
          assert_equal "Are you 18 or more?", f.current_question.label
          
          f.answer :no
          assert_equal "Fancy some Swiss chocolate?", f.current_question.label
          
          f.answer :yes
          assert_equal "Awesome! Do you prefer dark chocolate or milk chocolate?", f.current_question.label
          
          f.answer :milk
          
          assert f.ended?
        end
        
        assert_output(<<~TXT) { submission.print_out }
          - Are you 18 or more?
            > No
          - Fancy some Swiss chocolate?
            > Yes
          - Awesome! Do you prefer dark chocolate or milk chocolate?
            > Milk
        TXT
      end
    end
  end
  
  module UnitTests
    class BranchingTest < Minitest::Test
      def test_calling_with_a_wrong_answer
        b = Branching.new foo: "Foo", bar: "Bar", baz: "Baz"
        
        error = assert_raises(ArgumentError) do
          b.call :qux
        end
        
        assert_equal 'only foo, bar or baz are accepted answers, got qux', error.message
      end
      
      def test_branching_to_an_exit
        b = Branching.new foo: "Foo", bar: nil
        
        refute_nil b.call(:foo)
        assert_nil b.call(:bar)
      end
    end
    
    class ComparisonBranchingTest < Minitest::Test
      def test_calling
        b = ComparisonBranching.new 0..17 => "Question 1", 18.. => "Question 2"
        
        assert_equal "Question 2", b.call(20)
        assert_equal "Question 1", b.call(1)
      end
    end
  end
end
