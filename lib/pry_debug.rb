require 'pry'

require 'pry_debug/conditional_breakpoint'
require 'pry_debug/line_breakpoint'
require 'pry_debug/method_breakpoint'
require 'pry_debug/commands'

module PryDebug
  class << self
    # @return [Array<LineBreakpoint,MethodBreakpoint>] All the enabled breakpoints
    attr_reader   :breakpoints

    attr_accessor :breakpoint_count

    # @return [String, nil] File that PryDebug loads
    attr_accessor :file

    # @return [String, nil] If not nil, the file where PryDebug needs to stop
    #   (implying that next was called)
    attr_accessor :stepped_file

    # @return [true, false]  True if stepping
    attr_accessor :stepping

    # @return [Binding, nil] Binding where last_exception was raised
    attr_accessor :exception_binding

    # @return [Exception, nil] Last exception that PryDebug has heard of
    attr_accessor :last_exception

    # @return [true, false] True if PryDebug breaks on raise
    attr_accessor :break_on_raise

    attr_accessor :debugging
    attr_accessor :will_load

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
      @stepped_file     = nil
      @stepping         = false

      @exception_binding = nil
      @last_exception    = nil
      @break_on_raise    = false

      @debugging         = false

      @will_load         = false
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
        set_trace_func proc { |*args| PryDebug.trace_func(*args) }
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
            puts "returning back to where the exception was raised"

            catch(:resume_debugging!) do
              Pry.start(binding, :commands => ShortCommands)
            end
          else
            puts "context of the exception is unknown, starting pry into"
            puts "the exception."

            catch(:resume_debugging!) do
              Pry.start(ex, :commands => ShortCommands)
            end
          end
        end

        PryDebug.last_exception = PryDebug.exception_binding = nil
        PryDebug.debugging = false
        puts "execution terminated"
      else
        break # debugger wasn't started, leave now
      end
    end
  end

  # Starts Pry with access to ShortCommands
  # @param [Binding, object] binding Context to go to
  # @param [String, nil] file Current file. Used for the next command.
  def start_pry(binding, file = nil)
    ret = catch(:resume_debugging!) do
      Pry.start(binding, :commands => ShortCommands)
    end

    if ret == :next
      PryDebug.stepped_file = file
    end

    # In case trace_func was changed
    set_trace_func proc { |*args| PryDebug.trace_func(*args) }
  end

  def trace_func(event, file, line, method, binding, klass)
    # Ignore events in this file
    return if file && File.expand_path(file) == File.expand_path(__FILE__)

    case event
    when 'line'
      if PryDebug.stepped_file == file
        puts "stepped at #{file}:#{line}"
        PryDebug.stepped_file = nil

        start_pry binding, file
      elsif PryDebug.stepping
        puts "stepped at #{file}:#{line}"
        PryDebug.stepping = false

        start_pry binding, file
      elsif bp = PryDebug.line_breakpoints.find { |b| b.is_at?(file, line, binding) }
        puts "reached #{bp}"
        start_pry binding, file
      end
    when 'c-call', 'call'
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
        puts "reached #{bp}"
        start_pry binding, file
      end
    when 'raise'
      PryDebug.last_exception    = $!
      PryDebug.exception_binding = binding

      if PryDebug.break_on_raise
        puts "exception raised: #{$!.class}: #{$!.message}"
        start_pry binding, file
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

if $PROGRAM_NAME == __FILE__
  PryDebug.start
end
