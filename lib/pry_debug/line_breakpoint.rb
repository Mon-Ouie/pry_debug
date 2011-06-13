module PryDebug
  LineBreakpoint = Struct.new(:id, :file, :line) do
    include ConditionalBreakpoint

    def at_location?(other_file, other_line)
      return false unless line == other_line

      path = ""
      split_file(other_file).any? do |part|
        path = File.join(part, path).chomp('/')
        path == file
      end
    end

    def is_at?(other_file, other_line, binding)
      at_location?(other_file, other_line) && super(binding)
    end

    def split_file(file)
      ary = []

      loop do
        dirname, filename = File.split(file)

        ary << filename

        if dirname == '.'
          break
        elsif dirname == '/'
          ary << '/'
          break
        else
          file = dirname
        end
      end

      ary
    end

    def to_s
      "breakpoint #{id} at #{file}:#{line}#{super}"
    end
  end
end
