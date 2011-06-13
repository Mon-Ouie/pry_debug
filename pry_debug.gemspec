# -*- encoding: utf-8 -*-
Gem::Specification.new do |s|
  s.name        = "pry_debug"
  s.version     = "0.0.1"
  s.authors     = ["Mon ouïe"]
  s.email       = ["mon.ouie@gmail.com"]
  s.homepage    = "http://github.com/Mon-Ouie/pry_debug"

  s.summary     = "A pure-ruby debugger"
  s.description = <<EOD
A pure-ruby debugger. No more puts "HERE!!!" or p :var => var, :other => other
until you find what caused the bug. Just add a breakpoint and see the value of
any variable.
EOD

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- test/*`.split("\n")
  s.executables   = %q[pry_debug]
  s.require_paths = %q[lib]

  s.add_dependency "pry"
  s.add_development_dependency "riot"
end
