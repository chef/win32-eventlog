require "bundler/gem_tasks"
require "rake/clean"
require "rake/testtask"

CLEAN.include("**/*.gem", "**/*.rbc")

namespace :example do
  desc "Run the notify (tail) example program"
  task :notify do
    ruby "-Ilib examples/example_notify.rb"
  end

  desc "Run the read example program"
  task :read do
    ruby "-Ilib examples/example_read.rb"
  end

  desc "Run the write example program"
  task :write do
    ruby "-Ilib examples/example_write.rb"
  end
end

namespace :event_source do
  desc "Install the RubyMsg event source"
  task :install do
    sh "ruby -Ilib misc/install_msg.rb"
  end
end

desc "Check Linting and code style."
task :style do
  require "rubocop/rake_task"
  require "cookstyle/chefstyle"

  if RbConfig::CONFIG["host_os"] =~ /mswin|mingw|cygwin/
    # Windows-specific command, rubocop erroneously reports the CRLF in each file which is removed when your PR is uploaeded to GitHub.
    # This is a workaround to ignore the CRLF from the files before running cookstyle.
    sh "cookstyle --chefstyle -c .rubocop.yml --except Layout/EndOfLine"
  else
    sh "cookstyle --chefstyle -c .rubocop.yml"
  end
rescue LoadError
  puts "Rubocop or Cookstyle gems are not installed. bundle install first to make sure all dependencies are installed."
end

Rake::TestTask.new do |t|
  t.warning = true
  t.verbose = true
end

namespace :test do
  Rake::TestTask.new(:eventlog) do |t|
    t.warning    = true
    t.verbose    = true
    t.test_files = Dir["test/test_eventlog.rb"]
  end

  Rake::TestTask.new(:mc) do |t|
    t.warning    = true
    t.verbose    = true
    t.test_files = Dir["test/test_mc.rb"]
  end
end

begin
  require "yard" unless defined?(YARD)
  YARD::Rake::YardocTask.new(:docs)
rescue LoadError
  puts "yard is not available. bundle install first to make sure all dependencies are installed."
end

task :console do
  require "irb"
  require "irb/completion"
  ARGV.clear
  IRB.start
end

task default: :test
