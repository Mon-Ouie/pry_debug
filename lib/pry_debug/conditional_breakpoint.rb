module PryDebug
  module ConditionalBreakpoint
    attr_accessor :condition

    def is_at?(binding)
      condition ? binding.eval(condition) : true
    rescue Exception # error in the code
      false
    end

    def to_s
      condition ? " (if #{condition})" : ""
    end
  end
end
