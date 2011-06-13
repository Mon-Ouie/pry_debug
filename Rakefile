require 'rake'

task :test do
  load File.expand_path("test/run_all.rb", File.dirname(__FILE__))
end

task :install do
  ruby "-S gem build pry_debug.gemspec"
  ruby "-S gem install -l pry_debug"
end
