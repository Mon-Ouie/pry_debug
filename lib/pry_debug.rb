require 'pry'

require 'pry_debug/conditional_breakpoint'
require 'pry_debug/line_breakpoint'
require 'pry_debug/method_breakpoint'
require 'pry_debug/commands'

module PryDebug
  @breakpoints      = []
  @breakpoint_count = -1
  @file             = nil
  @stepped_file     = nil
  @stepping         = false

  @exception_binding = nil
  @last_exception    = nil

  class << self
    attr_reader :breakpoints
    attr_accessor :breakpoint_count
    attr_accessor :file
    attr_accessor :stepped_file
    attr_accessor :stepping
    attr_accessor :exception_binding
    attr_accessor :last_exception

    def line_breakpoints
      breakpoints.select { |bp| bp.is_a? LineBreakpoint }
    end

    def method_breakpoints
      breakpoints.select { |bp| bp.is_a? MethodBreakpoint }
    end

    def context_of_exception(ex)
      if ex == last_exception
        exception_binding
      end
    end
  end

  module_function
  def start
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

        puts "execution terminated"
      else
        break # debugger wasn't started, leave now
      end
    end
  end

  def start_pry(binding, file = nil)
    ret = catch(:resume_debugging!) do
      Pry.start(binding, :commands => ShortCommands)
    end

    if ret == :next
      Pry.stepped_file = file
    end

    # In case trace_func was changed
    set_trace_func proc { |*args| PryDebug.trace_func(*args) }
  end

  def trace_func(event, file, line, method, binding, klass)
    # Ignore events in this file
    return if File.expand_path(file) == File.expand_path(__FILE__)

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
      elsif bp = PryDebug.line_breakpoints.find { |bp| bp.is_at?(file, line, binding) }
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
