require File.expand_path("helpers.rb", File.dirname(__FILE__))

class InputTester
  def initialize(actions)
    @orig_actions = actions.dup
    @actions = actions
  end

  def readline(*)
    @actions.shift
  end

  def rewind
    @actions = @orig_actions.dup
  end
end

context "a PryDebug session" do
  helper(:clean_up) { PryDebug.clean_up }

  helper(:run_debugger) do |input|
    input  = InputTester.new(input)
    output = StringIO.new

    pry = Pry.new(:input => input, :output => output,
                  :commands => PryDebug::ShortCommands)
    pry.repl(TOPLEVEL_BINDING)

    output.string
  end

  setup { PryDebug }

  asserts(:breakpoints).size 0
  asserts(:line_breakpoints).size 0
  asserts(:method_breakpoints).size 0

  asserts(:file).nil

  denies(:stepping)
  asserts(:stepped_file).nil

  denies(:break_on_raise)
  denies(:debugging)

  context "after adding two breakpoints" do
    hookup do
      @output          = run_debugger(["b foo.rb:15", "b Foo#bar"]).split("\n")
      @breakpoint_list = run_debugger ["bl"]
    end

    asserts(:breakpoints).size 2
    asserts(:line_breakpoints).size 1
    asserts(:method_breakpoints).size 1

    asserts(:breakpoints).same_elements {
      topic.line_breakpoints + topic.method_breakpoints
    }

    asserts("output") { @output[0] }.matches "added breakpoint 0 at foo.rb:15"
    asserts("output") { @output[1] }.matches "added breakpoint 1 at Foo#bar"

    asserts("breakpoint list") { @breakpoint_list }.matches "breakpoint 0 at foo.rb:15"
    asserts("breakpoint list") { @breakpoint_list }.matches "breakpoint 1 at Foo#bar"

    context "line breakpoint" do
      setup do
        topic.line_breakpoints.first
      end

      asserts_topic.kind_of PryDebug::LineBreakpoint

      asserts(:condition).nil
      asserts(:file).equals "foo.rb"
      asserts(:line).equals 15
      asserts(:id).equals 0
    end

    context "method breakpoint" do
      setup do
        topic.method_breakpoints.first
      end

      asserts_topic.kind_of PryDebug::MethodBreakpoint

      asserts(:condition).nil
      asserts(:klass).equals "Foo"
      asserts(:name).equals "bar"
      asserts(:id).equals 1
    end

    context "method breakpoint after adding a condition" do
      setup do
        @output          = run_debugger [%{cond 1 @var == "foo"}]
        @breakpoint_list = run_debugger ["bl"]

        topic.method_breakpoints.first
      end

      asserts(:condition).equals %{@var == "foo"}
      asserts("output") { @output }.matches /condition set to @var == "foo"/
      asserts("breakpoint list") { @breakpoint_list }.matches <<desc.chomp
breakpoint 1 at Foo#bar (if @var == "foo")
desc

      context "and disabling it" do
        hookup do
          @output = run_debugger [%{uncond 1}]
          @breakpoint_list = run_debugger ["bl"]
        end

        asserts(:condition).nil

        asserts("output") { @output }.matches /condition unset/
        denies("breakpoint list") { @breakpoint_list }.matches /\(if .+\)/
      end
    end

    context "and deleting one" do
      hookup do
        @output          = run_debugger ["del 0"]
        @breakpoint_list = run_debugger ["bl"]
      end

      asserts(:breakpoints).size 1
      asserts(:line_breakpoints).size 0
      asserts(:method_breakpoints).size 1

      asserts("output") { @output }.matches /breakpoint 0 deleted/
      asserts("breakpoint list") { @breakpoint_list }.matches /breakpoint 1/
      denies("breakpoint list") { @breakpoint_list }.matches /breakpoint 0/
    end
  end

  context "after disabling condition on an unknown breakpoint" do
    hookup do
      @output = run_debugger ["uncond 0"]
    end

    asserts("output") { @output }.matches "error: could not find breakpoint 0"
  end

  context "after enableing condition on an unknown breakpoint" do
    hookup do
      @output = run_debugger ["cond 0 foo"]
    end

    asserts("output") { @output }.matches "error: could not find breakpoint 0"
  end

  context "after changing file" do
    hookup do
      @output = run_debugger ["f #{__FILE__}"]
    end

    asserts("output") { @output }.matches "debugged file set to #{__FILE__}"

    context "and running the debugger" do
      hookup do
        @output = nil

        catch :start_debugging! do
          @output = run_debugger ["r"]
        end
      end

      asserts("output") { @output }.nil
    end
  end

  context "running the debugger when file isn't set" do
    hookup do
      @output = nil

      catch :start_debugging! do
        @output = run_debugger ["r"]
      end
    end

    asserts("output") { @output }.matches "error: file is not set"
  end

  context "running the debugger when file doesn't exist" do
    hookup do
      @output = nil
      PryDebug.file = "#{__FILE__}_doesnt_exist.rb"

      catch :start_debugging! do
        @output = run_debugger ["r"]
      end
    end

    asserts("output") { @output }.matches "error: file does not exist"
  end

  context "after enabling break-on-raise" do
    hookup { @output = run_debugger ["bor"] }

    asserts("output") { @output }.matches "break on raise enabled"
    asserts(:break_on_raise)

    context "and disabling it" do
      hookup { @output = run_debugger ["bor"] }

      asserts("output") { @output }.matches "break on raise disabled"
      denies(:break_on_raise)
    end
  end

  teardown { clean_up }
end

run_tests if $0 == __FILE__
