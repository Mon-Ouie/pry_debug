require 'thread'

require 'pry'

require 'pry_debug/conditional_breakpoint'
require 'pry_debug/line_breakpoint'
require 'pry_debug/method_breakpoint'
require 'pry_debug/commands'

module PryDebug
  DefinitionFile = File.expand_path(__FILE__)

  class << self
    # @return [Array<LineBreakpoint,MethodBreakpoint>] All the enabled breakpoints
    attr_reader   :breakpoints

    attr_accessor :breakpoint_count

    # @return [String, nil] File that PryDebug loads
    attr_accessor :file

    # @return [String, nil] If not nil, the file where PryDebug needs to stop
    #   (implying that next was called)
    def stepped_file
      Thread.current[:__pry_debug_stepped_file]
    end

    def stepped_file=(val)
      Thread.current[:__pry_debug_stepped_file] = val
    end

    # @return [true, false]  True if stepping
    def stepping
      Thread.current[:__pry_debug_steppping]
    end

    def stepping=(val)
      Thread.current[:__pry_debug_stepping] = val
    end

    # @return [Binding, nil] Binding where last_exception was raised
    def exception_binding
      Thread.current[:__pry_debug_exception_binding]
    end

    def exception_binding=(b)
      Thread.current[:__pry_debug_exception_binding] = b
    end

    # @return [Exception, nil] Last exception that PryDebug has heard of
    def last_exception
      Thread.current[:__pry_debug_last_exception]
    end

    def last_exception=(ex)
      Thread.current[:__pry_debug_last_exception] = ex
    end

    # @return [true, false] True if PryDebug breaks on raise
    attr_accessor :break_on_raise

    attr_accessor :debugging
    attr_accessor :will_load

    attr_reader :mutex

    # @return [Array<LineBreakpoint>] Breakpoints on a line
    def line_breakpoints
      breakpoints.select { |bp| bp.is_a? LineBreakpoint }
    end

    # @return [Array<MethodBreakpoint>] Breakpoints on a method
    def method_breakpoints
      breakpoints.select { |bp| bp.is_a? MethodBreakpoint }
    end

    # @return [Binding, nil] Binding where the exception was raised, if still in
    #   memory.
    def context_of_exception(ex)
      if ex.equal? last_exception
        exception_binding
      end
    end

    # Resets PryDebug to its default state.
    def clean_up
      @breakpoints      = []
      @breakpoint_count = -1
      @file             = nil

      Thread.list.each do |th|
        th[:__pry_debug_stepped_file] = nil
        th[:__pry_debug_stepping]     = false

        th[:__pry_debug_exception_binding] = nil
        th[:__pry_debug_last_exception]    = nil
      end

      @break_on_raise    = false
      @debugging         = false
      @will_load         = true

      @mutex             = Mutex.new
    end
  end

  clean_up

  module_function

  # Starts the debguger.
  #
  # @param [true, false] load_file When set to false, PryDebug won't load
  #   a file, and simply enable the tracing and let the user setup breakpoints.
  def start(load_file = true)
    PryDebug.will_load = load_file

    # Importing user-defined commands.
    # NB: what about commands defined in both sets? Currently, user-defined
    # commands override PryDebug's. What about doing it the other way around?
    Pry.load_rc if Pry.config.should_load_rc # user might change Pry.commands
    Pry.config.should_load_rc = false # avoid loading config twice
    ShortCommands.import Pry.commands

    loop do
      should_start = catch(:start_debugging!) do
        Pry.start(TOPLEVEL_BINDING, :commands => ShortCommands)
      end

      if should_start == :now!
        set_trace_func trace_proc
        PryDebug.debugging = true

        return unless load_file

        begin
          load PryDebug.file
        rescue SystemExit
          # let this go
        rescue Exception => ex
          set_trace_func nil
          puts "unrescued exception: #{ex.class}: #{ex.message}"

          if binding = PryDebug.context_of_exception(ex)
            msg = "returning back to where the exception was raised"
            start_pry binding, nil, msg
          else
            msg =  "context of the exception is unknown, starting pry into\n"
            msg << "the exception."

            start_pry ex, nil, msg
          end
        end

        PryDebug.last_exception = PryDebug.exception_binding = nil
        PryDebug.debugging = false

        set_trace_func nil
        puts "execution terminated"
      else
        break # debugger wasn't started, leave now
      end
    end
  end

  # Starts Pry with access to ShortCommands
  # @param [Binding, object] binding Context to go to
  # @param [String, nil] file Current file. Used for the next command.
  # @param [String, nil] header Line to print before starting the debugger
  def start_pry(binding, file = nil, header = nil)
    PryDebug.synchronize do
      puts header if header

      ret = catch(:resume_debugging!) do
        Pry.start(binding, :commands => ShortCommands)
      end

      if ret == :next
        PryDebug.stepped_file = file
      end

      # In case trace_func was changed
      set_trace_func trace_proc
    end
  end

  def synchronize(&block)
    PryDebug.mutex.synchronize(&block)
  end

  def trace_proc
    proc do |*args|
      PryDebug.trace_func(*args)
    end
  end

  def trace_func(event, file, line, method, binding, klass)
    # Ignore events in this file
    return if file && File.expand_path(file) == DefinitionFile

    case event
    when 'line'
      if PryDebug.stepped_file == file
        PryDebug.stepped_file = nil
        start_pry binding, file, "stepped at #{file}:#{line} in #{Thread.current}"
      elsif PryDebug.stepping
        PryDebug.stepping = false
        start_pry binding, file, "stepped at #{file}:#{line} in #{Thread.current}"
      elsif bp = PryDebug.line_breakpoints.find { |b| b.is_at?(file, line, binding) }
        start_pry binding, file, "reached #{bp} in #{Thread.current}"
      end
    when 'c-call', 'call'
      return unless Module === klass

      # Whether we are calling a class method or an instance method, klass
      # is the same thing, making it harder to guess if it's a class or an
      # instance method.
      #
      # In case of C method calls, self cannot be trusted. Both will be tried,
      # unless we can find out there is only an instance method of that name
      # using instance_methods.
      #
      # Otherwise, assume it's an instance method if self is_a? klass
      #
      # Notice that since self could be a BasicObject, it may not respond to
      # is_a? (even when not breaking on BasicObject#thing, this code may be
      # triggered).
      class_method, try_both = if event == "call"
                                 [!(klass === binding.eval("self")), false]
                               else
                                 if (klass.instance_methods & klass.methods).include? method
                                   [false, true]
                                 elsif klass.instance_methods.include? method
                                   [false, false]
                                 elsif klass.methods.include? method
                                   [true, false]
                                 else # should never happen
                                   [false, true]
                                 end
                               end

      bp = PryDebug.method_breakpoints.find do |b|
        if try_both
          b.is_at?(klass, method.to_s, true, binding) ||
            b.is_at?(klass, method.to_s, false, binding)
        else
          b.is_at?(klass, method.to_s, class_method, binding)
        end
      end

      if bp
        start_pry binding, file, "reached #{bp} in #{Thread.current}"
      end
    when 'raise'
      return unless $!

      PryDebug.last_exception    = $!
      PryDebug.exception_binding = binding

      if PryDebug.break_on_raise
        msg = "exception raised in #{Thread.current}: #{$!.class}: #{$!.message} "
        start_pry binding, file, msg
      end
    end
  end

  def add_line_breakpoint(file, line)
    bp = LineBreakpoint.new(PryDebug.breakpoint_count += 1, file, line)
    PryDebug.breakpoints << bp
    bp
  end

  def add_method_breakpoint(klass, method, class_method)
    bp = MethodBreakpoint.new(PryDebug.breakpoint_count += 1, klass, method,
                              class_method)
    PryDebug.breakpoints << bp
    bp
  end
end
