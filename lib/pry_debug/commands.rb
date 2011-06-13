module PryDebug
  Commands = Pry::CommandSet.new do
    command "breakpoint", "adds a breakpoint" do |argument|
      if argument =~ /(.+):(\d+)/
        file, line = $1, $2.to_i

        bp = PryDebug.add_line_breakpoint(file, line)
        output.puts "added #{bp}"
      elsif argument =~ /(.+)(#|\.|::)([^#\.:]+)/
        klass, separator, meth = $1, $2, $3
        class_method = (separator != "#")

        bp = PryDebug.add_method_breakpoint(klass, meth, class_method)
        output.puts "addded #{bp}"
      else
        output.puts "usage: breakpoint FILE:LINE"
        output.puts "    or breakpoint CLASS(#|.|::)METHOD"
        output.puts
        output.puts "FILE can be foo.rb or /full/path/to/foo.rb."
        output.puts "# as a separator means instance method. . and :: both mean"
        output.puts "class method."
      end
    end

    command "cond", "adds a condition to a breakpoint" do |id, *code|
      if id =~ /^\d+$/ && (bp = PryDebug.breakpoints.find { |b| b.id == id.to_i })
        bp.condition = code.join(" ")
        output.puts "condition set to #{bp.condition}"
      else
        output.puts "error: could not find breakpoint #{id}"
      end
    end

    command "uncond", "removes the condition of a breakpoint" do |id|
      if id =~ /^\d+$/ && (bp = PryDebug.breakpoints.find { |b| b.id == id.to_i })
        bp.condition = nil
        output.puts "condition unset"
      else
        output.puts "error: could not find breakpoint #{id}"
      end
    end

    command "file", "sets the file to start the debugger at" do |file|
      PryDebug.file = file
      output.puts "debugged file set to #{file}"
    end

    command "run", "starts the debugger" do |file|
      PryDebug.file = file if file

      if PryDebug.file and File.exist? PryDebug.file
        throw :start_debugging!, :now!
      else
        output.puts "error: file does not exist: #{PryDebug.file}"
        output.puts "create it or set a new file using the 'file' command."
      end
    end

    command "continue", "resumes execution" do
      throw :resume_debugging!
    end

    command "next", "resumes execution until next line in the same file" do
      throw :resume_debugging!, :next
    end

    command "step", "resumes execution until next line gets executed" do
      PryDebug.stepping = true
      throw :resume_debugging!
    end
  end

  ShortCommands = Pry::CommandSet.new Commands do
    alias_command "f",  "file"
    alias_command "b",  "breakpoint"
    alias_command "bp", "breakpoint"
    alias_command "r",  "run"
    alias_command "c",  "continue"
    alias_command "n",  "next"
    alias_command "s",  "step"
  end
end
