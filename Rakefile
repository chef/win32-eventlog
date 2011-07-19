require 'rake'
require 'rake/testtask'
require 'rake/clean'

CLEAN.include('**/*.gem', '**/*.rbc')

namespace :gem do
  desc 'Create the win32-eventlog gem'
  task :create do
    spec = eval(IO.read('win32-eventlog.gemspec'))
    Gem::Builder.new(spec).build
  end

  desc 'Install the win32-eventlog library'
  task :install => [:clean] do
    ruby 'win32-eventlog.gemspec'
    file = Dir["*.gem"].first
    sh "gem install #{file}"
  end
end

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

namespace :test do
  Rake::TestTask.new(:all) do |t|
    t.warning = true
    t.verbose = true
  end

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

task :default => 'test:all'
