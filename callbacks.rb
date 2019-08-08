module Callbacks
  VERSION = '0.2'.freeze

  VALID_OPTION_KEYS = [:if].freeze

  def self.included(base)
    base.instance_variable_set(:@before_callbacks, {})
    base.instance_variable_set(:@after_callbacks, {})
    base.singleton_class.attr_accessor(:before_callbacks, :after_callbacks)
    base.extend ClassMethods
    base.include InstanceMethods
  end

  module ClassMethods

    def before(method_name, callback_method_name = nil, options = {}, &callback_proc)
      callback_method_name_or_proc = callback_proc || callback_method_name
      unless [Symbol, String, Proc].include? callback_method_name_or_proc.class
        raise ArgumentError, "Only `Symbol`, `String` or `Proc` allowed for `method_name`, but is #{callback_method_name_or_proc.class}"
      end

      invalid_option_keys = options.keys - VALID_OPTION_KEYS
      unless invalid_option_keys.empty?
        raise ArgumentError, "Invalid `options` keys: #{invalid_option_keys}. Valid are only: #{VALID_OPTION_KEYS}"
      end
      if options[:if] && !([Symbol, String, Proc].include? options[:if].class)
        raise ArgumentError, "Only `Symbol`, `String` or `Proc` allowed for `options[:if]`, but is #{options[:if].class}"
      end

      self.before_callbacks ||= {}
      self.before_callbacks[method_name.to_sym] ||= []
      self.before_callbacks[method_name.to_sym] << [callback_method_name_or_proc, options[:if]]
    end

    def before!(method_name, *remaining_args)
      raise ArgumentError, "`#{method_name}` is not or not yet defined for #{self}" unless method_defined? method_name
      before(method_name, *remaining_args)
    end

    # TODO
    # def around
    # end

    def after(method_name, callback_method_name = nil, options = {}, &callback_proc)
      callback_method_name_or_proc = callback_proc || callback_method_name
      unless [Symbol, String, Proc].include? callback_method_name_or_proc.class
        raise ArgumentError, "Only `Symbol`, `String` or `Proc` allowed for `method_name`, but is #{callback_method_name_or_proc.class}"
      end

      invalid_option_keys = options.keys - VALID_OPTION_KEYS
      unless invalid_option_keys.empty?
        raise ArgumentError, "Invalid `options` keys: #{invalid_option_keys}. Valid are only: #{VALID_OPTION_KEYS}"
      end
      if options[:if] && ![Symbol, String, Proc].include?(options[:if].class)
        raise ArgumentError, "Only `Symbol`, `String` or `Proc` allowed for `options[:if]`, but is #{options[:if].class}"
      end

      self.after_callbacks ||= {}
      self.after_callbacks[method_name.to_sym] ||= []
      self.after_callbacks[method_name.to_sym] << [callback_method_name_or_proc, options[:if]]
    end

    def after!(method_name, *remaining_args)
      raise ArgumentError, "`#{method_name}` is not or not yet defined for #{self}" unless method_defined? method_name
      before(method_name, *remaining_args)
    end

    def attr_writer_with_callbacks(*instance_variable_names)
      instance_variable_names.each do |instance_variable_name|
        define_method "#{instance_variable_name}=" do |value|
          run_callbacks "#{instance_variable_name}=", value do
            instance_variable_set("@#{instance_variable_name}", value)
          end
        end
      end
    end

    # DONT USE THE INSTANCE VARIABLE THAT IS GONNA BE CALLED EVERY TICK! (i.e. @sprite);
    # ... as it can potentially slow down (to varying degrees) your game
    # better just eager-evaluate the value and set or cache it somehow deterministically on write / changes (to its value dependencies)
    # therefore, probably you'd want to use attr_writer_with_callbacks above instead to cache the value
    def attr_reader_with_callbacks(*instance_variable_names)
      instance_variable_names.each do |instance_variable_name|
        define_method instance_variable_name do
          run_callbacks instance_variable_name do
            instance_variable_get("@#{instance_variable_name}")
          end
        end
      end
    end

    def attr_accessor_with_callbacks(*instance_variable_names)
      attr_writer_with_callbacks(*instance_variable_names)
      attr_reader_with_callbacks(*instance_variable_names)
    end
  end

  module InstanceMethods

    def run_callbacks(method_name, *args)
      before_callbacks = self.class.before_callbacks[method_name.to_sym]

      unless before_callbacks.nil?
        before_callbacks.each do |before_callback, options_if|
          is_condition_truthy = true

          if options_if
            is_condition_truthy = instance_exec *args, &options_if
          end

          if is_condition_truthy
            if before_callback.is_a? Proc
              instance_exec *args, &before_callback
            else
              send before_callback
            end
          end
        end
      end

      yield_value = yield

      after_callbacks = self.class.after_callbacks[method_name.to_sym]

      unless after_callbacks.nil?
        after_callbacks.each do |after_callback, options_if|
          is_condition_truthy = true

          if options_if
            is_condition_truthy = instance_exec *args, &options_if
          end

          if is_condition_truthy
            if after_callback.is_a? Proc
              instance_exec *args, &after_callback
            else
              send after_callback
            end
          end
        end
      end

      yield_value
    end
  end
end
