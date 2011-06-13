module PryDebug
  MethodBreakpoint = Struct.new(:id, :klass, :name, :class_method) do
    include ConditionalBreakpoint

    alias class_method? class_method

    def at_method?(other_class, other_name, other_class_method)
      if klass == other_class.to_s && name == other_name &&
          class_method == other_class_method
        true # exactly the same parameters
      elsif class_method != other_class_method
        false
      else # find out if the method we are referring to is the same as the one
           # that was called.
        if klass = actual_class
          other_method = if other_class_method && has_class_method?(other_class, other_name)
                           (class << other_class; self; end).instance_method(other_name)
                         elsif !other_class_method && has_instance_method?(other_class, other_name)
                           other_class.instance_method(other_name)
                         end

          if referred_method && other_method
            (other_class < klass || other_class == klass) &&
              ((referred_method == other_method) ||
               (referred_method.name  == other_method.name &&
                referred_method.owner == other_method.owner))
          else
            false
          end
        else
          false # can't get information about the class
        end
      end
    end

    def is_at?(other_class, other_name, other_class_method, binding)
      at_method?(other_class, other_name, other_class_method) && super(binding)
    end

    def to_s
      "breakpoint #{id} at #{method_name}#{super}"
    end

    def separator
      class_method ? "." : "#"
    end

    def method_name
      klass + separator + name
    end

    def referred_method
      if klass = actual_class
        @referred_method ||= if class_method? && has_class_method?(klass, name)
                               (class << klass; self; end).instance_method(name)
                             elsif !class_method && has_instance_method?(klass, name)
                               klass.instance_method(name)
                             end
      end
    end

    def actual_class
      @actual_class ||= klass.split('::').inject(Object) do |mod, const_name|
        if mod.respond_to?(:const_defined?) && mod.const_defined?(const_name)
          mod.const_get const_name
        else
          break
        end
      end
    end

    def has_instance_method?(klass, method)
      (klass.private_instance_methods + klass.instance_methods).any? do |m|
        m.to_s == method
      end
    end

    def has_class_method?(klass, method)
      (klass.private_methods + klass.methods).any? do |m|
        m.to_s == method
      end
    end
  end
end
