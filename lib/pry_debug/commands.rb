module PryDebug
  Commands = Pry::CommandSet.new do
    command "breakpoint", "adds a breakpoint" do |argument, *|
      if argument =~ /(.+):(\d+)/
        file, line = $1, $2.to_i

        bp = PryDebug.add_line_breakpoint(file, line)
        output.puts "added #{bp}"
      elsif argument =~ /(.+)(#|\.|::)([^#\.:]+)/
        klass, separator, meth = $1, $2, $3
        class_method = (separator != "#")

        bp = PryDebug.add_method_breakpoint(klass, meth, class_method)
        output.puts "added #{bp}"
      else
        output.puts "usage: breakpoint FILE:LINE"
        output.puts "    or breakpoint CLASS(#|.|::)METHOD"
        output.puts
        output.puts "FILE can be foo.rb or /full/path/to/foo.rb."
        output.puts "# as a separator means instance method. . and :: both mean"
        output.puts "class method."
      end
    end

    command "breakpoint-list", "prints breakpoint list" do
      output.puts PryDebug.breakpoints
    end

    command "delete", "deletes a breakpoint" do |id, *|
      PryDebug.breakpoints.reject! { |b| b.id == id.to_i }
      output.puts "breakpoint #{id} deleted"
    end

    command "cond", "adds a condition to a breakpoint" do
      id = string = nil
      if arg_string =~ /^(\d+) (.+)$/
        id, string = [$1.to_i, $2]
      else
        output.puts "usage: cond ID CODE"
        next
      end

      if bp = PryDebug.breakpoints.find { |b| b.id == id }
        bp.condition = string
        output.puts "condition set to #{bp.condition}"
      else
        output.puts "error: could not find breakpoint #{id}"
      end
    end

    command "uncond", "removes the condition of a breakpoint" do |id, *|
      if id =~ /^\d+$/ && (bp = PryDebug.breakpoints.find { |b| b.id == id.to_i })
        bp.condition = nil
        output.puts "condition unset"
      else
        output.puts "error: could not find breakpoint #{id}"
      end
    end

    command "file", "sets the file to start the debugger at" do |file, *|
      PryDebug.file = file
      output.puts "debugged file set to #{file}"
    end

    command "run", "starts the debugger" do |file, *|
      if PryDebug.debugging
        output.puts "error: debugger already started"
        next
      end

      PryDebug.file = file if file

      if PryDebug.file and File.exist? PryDebug.file
        throw :start_debugging!, :now!
      else
        if PryDebug.file
          output.puts "error: file does not exist: #{PryDebug.file}"
        else
          output.puts "error: file is not set: #{PryDebug.file}"
        end

        output.puts "create it or set a new file using the 'file' command."
      end
    end

    command "continue", "resumes execution" do
      if !PryDebug.debugging
        output.puts "error: debugger hasn't been started yet"
      else
        throw :resume_debugging!
      end
    end

    command "next", "resumes execution until next line in the same file" do
      if !PryDebug.debugging
        output.puts "error: debugger hasn't been started yet"
      else
        throw :resume_debugging!, :next
      end
    end

    command "step", "resumes execution until next line gets executed" do
      PryDebug.stepping = true

      if PryDebug.debugging
        throw :resume_debugging!
      else # just start debugging with stepping set to true
        if PryDebug.file and File.exist? PryDebug.file
          throw :start_debugging!, :now!
        else
          output.puts "error: file does not exist: #{PryDebug.file}"
          output.puts "create it or set a new file using the 'file' command."
        end
      end
    end

    command "break-on-raise", "toggles break on raise" do
      PryDebug.break_on_raise = !PryDebug.break_on_raise

      if PryDebug.break_on_raise
        output.puts "break on raise enabled"
      else
        output.puts "break on raise disabled"
      end
    end
  end

  ShortCommands = Pry::CommandSet.new Commands do
    alias_command "f",   "file"
    alias_command "b",   "breakpoint"
    alias_command "bp",  "breakpoint"
    alias_command "bl",  "breakpoint-list"
    alias_command "del", "delete"
    alias_command "d",   "delete"
    alias_command "r",   "run"
    alias_command "c",   "continue"
    alias_command "n",   "next"
    alias_command "s",   "step"
    alias_command "bor", "break-on-raise"
  end
end
