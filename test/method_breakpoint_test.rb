require File.expand_path("helpers.rb", File.dirname(__FILE__))

context "a method breakpoint" do
  setup { PryDebug::MethodBreakpoint.new(2, "Time", "new", true) }

  asserts(:condition).nil
  asserts(:klass).equals "Time"
  asserts(:name).equals "new"
  asserts(:id).equals 2

  asserts(:actual_class).equals Time
  asserts(:referred_method).equals((class << Time; self; end).instance_method(:new))

  asserts(:to_s).equals "breakpoint 2 at Time.new"

  asserts(:is_at?, Time, "new", true, binding)
  asserts(:is_at?, Class.new(Time), "new", true, binding)

  asserts(:is_at?, (class << Time; self; end), "new", false, binding)

  denies(:is_at?, Class, "new", false, binding)
  denies(:is_at?, Time, "new", false, binding)
  denies(:is_at?, String, "new", true, binding)
  # "now" doesn't pass on rbx because it's an alias
  denies(:is_at?, Time, "parse", true, binding)
  denies(:is_at?, Class.new(Time) {def self.new;end}, "new", true, binding)
end

context "a method breakpoint on an instance method" do
  setup { PryDebug::MethodBreakpoint.new(2, "String", "size", false) }

  asserts(:condition).nil
  asserts(:klass).equals "String"
  asserts(:name).equals "size"
  asserts(:id).equals 2

  asserts(:actual_class).equals String
  asserts(:referred_method).equals String.instance_method(:size)

  asserts(:to_s).equals "breakpoint 2 at String#size"

  asserts(:is_at?, String, "size", false, binding)
  # in 1.8, aliased methods aren't equal
  asserts(:is_at?, String, "length", false, binding) if RUBY_VERSION >= "1.9"
  asserts(:is_at?, Class.new(String), "size", false, binding)

  denies(:is_at?, String, "size", true, binding)
  denies(:is_at?, Time, "size", false, binding)
  denies(:is_at?, String, "foo", false, binding)
  denies(:is_at?, Class.new(String) {def size;end}, "size", false, binding)
end

context "a method breakpoint with unknown method" do
  setup { PryDebug::MethodBreakpoint.new(2, "Time", "foo", true) }

  asserts(:actual_class).equals Time
  asserts(:referred_method).nil

  denies(:is_at?, Class.new(Time), "foo", true, binding)
  denies(:is_at?, Time, "now", false, binding)
  denies(:is_at?, String, "now", true, binding)
  denies(:is_at?, Time, "new", true, binding)
  denies(:is_at?, Class.new(Time) {def self.now;end}, "now", true, binding)
end

context "a method breakpoint with unknown class" do
  setup { PryDebug::MethodBreakpoint.new(2, "Bar", "foo", true) }

  asserts(:actual_class).nil
  asserts(:referred_method).nil

  denies(:is_at?, Time, "foo", true, binding)
  denies(:is_at?, Class.new(Time), "foo", true, binding)
  denies(:is_at?, Time, "now", false, binding)
  denies(:is_at?, String, "now", true, binding)
  denies(:is_at?, Time, "new", true, binding)
  denies(:is_at?, Class.new {def self.now;end}, "foo", true, binding)
end

context "a method breakpoint with a non-class" do
  setup { PryDebug::MethodBreakpoint.new(2, "File::SEPARATOR", "size", true) }

  asserts(:actual_class).nil
  asserts(:referred_method).nil

  denies(:is_at?, File::SEPARATOR, "size", true, binding)
  denies(:is_at?, String, "size", false, binding)
end

run_tests if $0 == __FILE__
