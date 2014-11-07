# -*- encoding: utf-8 -*-

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)

require 'pry_debug/version'

Gem::Specification.new do |s|
  s.name        = "pry_debug"
  s.version     = PryDebug::Version
  s.authors     = ["Mon ouïe"]
  s.email       = ["mon.ouie@gmail.com"]
  s.homepage    = "http://github.com/Mon-Ouie/pry_debug"

  s.summary     = "A pure-ruby debugger"
  s.description = <<EOD
A pure-ruby debugger. No more puts "HERE!!!" or p :var => var, :other => other
until you find what caused the bug. Just add a breakpoint and see the value of
any variable.
EOD

  s.files  = Dir["lib/**/*.rb"]
  s.files += Dir["test/**/*.rb"]
  s.files << "bin/pry_debug"

  s.files << "README.md" << "LICENSE"

  s.executables   = %w[pry_debug]
  s.require_paths = %w[lib]

  s.add_dependency "pry", "~> 0.10"
  s.add_development_dependency "riot"
end
