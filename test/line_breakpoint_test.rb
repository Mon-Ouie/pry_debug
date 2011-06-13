require File.expand_path("helpers.rb", File.dirname(__FILE__))

context "a line breakpoint" do
  setup { PryDebug::LineBreakpoint.new(4, "test/foo.rb", 16) }

  asserts(:condition).nil
  asserts(:file).equals "test/foo.rb"
  asserts(:line).equals 16
  asserts(:id).equals 4

  asserts(:to_s).equals "breakpoint 4 at test/foo.rb:16"

  asserts(:is_at?, "test/foo.rb", 16, binding)
  asserts(:is_at?, "foo/test/foo.rb", 16, binding)
  asserts(:is_at?, "/bar/test/foo.rb", 16, binding)

  denies(:is_at?, "test/foo.rb", 17, binding)
  denies(:is_at?, "foo.rb", 16, binding)
  denies(:is_at?, "oo.rb", 16, binding)
  denies(:is_at?, "est/foo.rb", 16, binding)
  denies(:is_at?, "test/bar.rb", 16, binding)
end

run_tests if $0 == __FILE__
