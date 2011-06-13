require File.expand_path("helpers.rb", File.dirname(__FILE__))

context "a conditional line breakpoint" do
  setup do
    bp = PryDebug::LineBreakpoint.new(1, "test.rb", 10)
    bp.condition = "n == 0"
    bp
  end

  asserts(:condition).equals "n == 0"
  asserts(:to_s).equals "breakpoint 1 at test.rb:10 (if n == 0)"

  context "when causing an exception" do
    denies(:is_at?, "test.rb", 10, binding)
  end

  context "when condition isn't met" do
    n = -1
    denies(:is_at?, "test.rb", 10, binding)
  end

  context "when condition is met" do
    n = 0
    asserts(:is_at?, "test.rb", 10, binding)
    denies(:is_at?, "test.rb", 11, binding)
    denies(:is_at?, "foo.rb", 10, binding)
  end
end

context "a conditional method breakpoint" do
  setup do
    bp = PryDebug::MethodBreakpoint.new(1, "String", "try_convert", true)
    bp.condition = "n == 0"
    bp
  end

  asserts(:condition).equals "n == 0"
  asserts(:to_s).equals "breakpoint 1 at String.try_convert (if n == 0)"

  context "when causing an exception" do
    denies(:is_at?, String, "try_convert", true, binding)
  end

  context "when condition isn't met" do
    n = -1
    denies(:is_at?, String, "try_convert", true, binding)
  end

  context "when condition is met" do
    n = 0
    asserts(:is_at?, String, "try_convert", true, binding)

    denies(:is_at?, Array, "try_convert", true, binding)
    denies(:is_at?, String, "new", true, binding)
    denies(:is_at?, String, "try_convert", false, binding)
  end
end


run_tests if $0 == __FILE__
