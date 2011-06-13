$:.unshift File.expand_path('../lib', File.dirname(__FILE__))

require 'riot'
require 'pry_debug'

Riot.reporter = Riot::PrettyDotMatrixReporter
Riot.alone!

def run_tests
  exit Riot.run.success?
end
