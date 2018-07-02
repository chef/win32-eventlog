require 'bundler/gem_tasks'
require 'rake'
require 'rake/clean'
require 'rake/testtask'

CLEAN.include('**/*.gem', '**/*.rbc')


namespace :example do
  desc 'Run the notify (tail) example program'
  task :notify do
    ruby '-Ilib examples/example_notify.rb'
  end

  desc 'Run the read example program'
  task :read do
    ruby '-Ilib examples/example_read.rb'
  end

  desc 'Run the write example program'
  task :write do
    ruby '-Ilib examples/example_write.rb'
  end
end

namespace :event_source do
  desc 'Install the RubyMsg event source'
  task :install do
    sh "ruby -Ilib misc/install_msg.rb"
  end
end

Rake::TestTask.new do |t|
  t.warning = true
  t.verbose = true
end

namespace :test do
  Rake::TestTask.new(:eventlog) do |t|
    t.warning    = true
    t.verbose    = true
    t.test_files = Dir['test/test_eventlog.rb']
  end

  Rake::TestTask.new(:mc) do |t|
    t.warning    = true
    t.verbose    = true
    t.test_files = Dir['test/test_mc.rb']
  end
end

task :default => :test
