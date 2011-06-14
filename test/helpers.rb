$:.unshift File.expand_path('../lib', File.dirname(__FILE__))

require 'riot'
require 'pry_debug'

Riot.reporter = Riot::PrettyDotMatrixReporter
Riot.alone!

Pry.config.should_load_rc  = false
Pry.config.plugins.enabled = false
Pry.config.history.load    = false
Pry.config.history.save    = false

Pry.color = false
Pry.pager = false

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

def run_debugger(input)
  input  = InputTester.new(input)
  output = StringIO.new

  pry = Pry.new(:input => input, :output => output,
                :commands => PryDebug::ShortCommands)
  pry.repl(TOPLEVEL_BINDING)

  output.string
end

def run_tests
  exit Riot.run.success?
end
