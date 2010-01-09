require 'rake'
require 'rake/testtask'

desc 'Install win32-eventlog and win32-mc (non-gem)'
task :install do
   dest = File.join(Config::CONFIG['sitelibdir'], 'win32')
   Dir.mkdir(dest) unless File.exists? dest
   cp 'lib/win32/eventlog.rb', dest, :verbose => true
   cp 'lib/win32/mc.rb', dest, :verbose => true
end

desc 'Install the win32-eventlog library as a gem'
task :install_gem do
   ruby 'win32-eventlog.gemspec'
   file = Dir["*.gem"].first
   sh "gem install #{file}"
end

desc 'Run the notify (tail) example program'
task :example_notify do
   ruby '-Ilib examples/example_notify.rb'end

desc 'Run the read example program'
task :example_read do
   ruby '-Ilib examples/example_read.rb'end

desc 'Run the write example program'
task :example_write do
   ruby '-Ilib examples/example_write.rb'end

Rake::TestTask.new(:test) do |t|
   t.warning = true
   t.verbose = true
end

Rake::TestTask.new(:test_eventlog) do |t|
   t.warning    = true
   t.verbose    = true
   t.test_files = Dir['test/test_eventlog.rb']
end

Rake::TestTask.new(:test_mc) do |t|
   t.warning    = true
   t.verbose    = true
   t.test_files = Dir['test/test_mc.rb']
end
