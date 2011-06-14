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

def run_tests
  exit Riot.run.success?
end
