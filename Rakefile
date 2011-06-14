require 'rake'

task :test do
  path = File.expand_path("test/run_all.rb", File.dirname(__FILE__))

  if defined? RUBY_ENGINE and RUBY_ENGINE =~ /jruby/i
    ruby path
  else
    load path
  end
end

task :install do
  ruby "-S gem build pry_debug.gemspec"
  ruby "-S gem install -l pry_debug"
end
