require_relative 'callbacks.rb'
require 'test/unit.rb'

class TestCallbacks < Test::Unit::TestCase

  def test_before_bang_should_raise_error_if_method_not_defined
    assert_raise ArgumentError do
      Class.new do
        include Callbacks

        before! :bar, :say_hi_first

        def bar
        end

        def say_hi_first
          puts 'Hi'
        end
      end
    end

    assert_nothing_raised do
      Class.new do
        include Callbacks

        def bar
        end

        before! :bar, :say_hi_first

        def say_hi_first
          puts 'Hi'
        end
      end
    end
  end

  def test_after_bang_should_raise_error_if_method_not_defined
    assert_raise ArgumentError do
      Class.new do
        include Callbacks

        after! :bar, :say_hi_first

        def bar
        end

        def say_hi_first
          puts 'Hi'
        end
      end
    end

    assert_nothing_raised do
      Class.new do
        include Callbacks

        def bar
        end

        after! :bar, :say_hi_first

        def say_hi_first
          puts 'Hi'
        end
      end
    end
  end

  def test_before_should_not_raise_error_if_method_not_defined
    assert_nothing_raised do
      Class.new do
        include Callbacks

        before :bar, :say_hi_first

        def say_hi_first
          puts 'Hi'
        end
      end
    end
  end

  def test_after_should_not_raise_error_if_method_not_defined
    assert_nothing_raised do
      Class.new do
        include Callbacks

        after :bar, :say_hi_first

        def say_hi_first
          puts 'Hi'
        end
      end
    end
  end

  def test_run_callbacks_should_run_defined_callbacks_for_that_method
    klass = Class.new do
      include Callbacks

      attr_accessor :test_string_sequence

      def initialize
        @test_string_sequence = []
      end

      # below is intentionally defined not in order, for sequence testing

      before :bar, :say_hi_first

      after :bar, :say_goodbye

      before :bar do
        @test_string_sequence << 'Hello'
      end

      after :bar do
        @test_string_sequence << 'Paalam'
      end

      def say_hi_first
        @test_string_sequence << 'Hi'
      end

      def say_goodbye
        @test_string_sequence << 'Goodbye'
      end

      def bar
        run_callbacks __method__ do
          @test_string_sequence << 'bar is called'
          @bar
        end
      end
    end

    instance = klass.new
    instance.bar

    assert_equal instance.test_string_sequence, ['Hi', 'Hello', 'bar is called', 'Goodbye', 'Paalam']
  end

  def test_conditional_callbacks
    klass = Class.new do
      include Callbacks

      attr_accessor :test_string_sequence, :baz
      attr_writer_with_callbacks :bar

      def initialize
        @test_string_sequence = []
      end

      before :bar=, :do_a, if: -> (arg) { arg == 'hooman' && @baz = true }
      before :bar=, :do_b, if: -> (arg) { arg == 'hooman' && @baz = false }
      before :bar=, :do_c, if: -> (arg) { arg == 'dooge' && @baz = true }
      before :bar=, if: -> (arg) { arg == 'dooge' && @baz = true } do
        do_d
      end

      def do_a
        @test_string_sequence << 'a'
      end

      def do_b
        @test_string_sequence << 'b'
      end

      def do_c
        @test_string_sequence << 'c'
      end

      def do_d
        @test_string_sequence << 'd'
      end
    end

    instance = klass.new
    instance.baz = true
    instance.bar = 'dooge'
    assert_equal instance.test_string_sequence, ['c', 'd']
  end

  def test_attr_writer_with_callbacks_should_define_attr_writer_for_instance_variables_with_callbacks
    klass = Class.new do
      include Callbacks

      attr_accessor :test_string_sequence
      attr_writer_with_callbacks :bar

      def initialize
        @test_string_sequence = []
      end

      # below is intentionally defined not in order, for sequence testing

      before :bar=, :say_hi_first

      after :bar=, :say_goodbye

      before :bar= do |arg|
        @test_string_sequence << 'Hello'
        @test_string_sequence << arg
      end

      after :bar= do |arg|
        @test_string_sequence << 'Paalam'
        @test_string_sequence << arg
      end

      def say_hi_first
        @test_string_sequence << 'Hi'
      end

      def say_goodbye
        @test_string_sequence << 'Goodbye'
      end
    end

    instance = klass.new
    instance.bar = 'someval'

    assert_equal instance.instance_variable_get(:@bar), 'someval'
    assert_equal instance.test_string_sequence, ['Hi', 'Hello', 'someval', 'Goodbye', 'Paalam', 'someval']
  end

  def test_attr_reader_with_callbacks_should_define_attr_reader_for_instance_variables_with_callbacks
    klass = Class.new do
      include Callbacks

      attr_accessor :test_string_sequence
      attr_reader_with_callbacks :bar

      def initialize
        @test_string_sequence = []
      end

      # below is intentionally defined not in order, for sequence testing

      before :bar, :say_hi_first

      after :bar, :say_goodbye

      before :bar do
        @test_string_sequence << 'Hello'
      end

      after :bar do
        @test_string_sequence << 'Paalam'
      end

      def say_hi_first
        @test_string_sequence << 'Hi'
      end

      def say_goodbye
        @test_string_sequence << 'Goodbye'
      end
    end

    instance = klass.new
    instance.instance_variable_set(:@bar, 'someval')

    assert_equal instance.bar, 'someval'
    assert_equal instance.test_string_sequence, ['Hi', 'Hello', 'Goodbye', 'Paalam']
  end
end
