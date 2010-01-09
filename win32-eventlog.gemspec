require 'rubygems'

spec = Gem::Specification.new do |gem|
   gem.name       = 'win32-eventlog'
   gem.version    = '0.5.2'
   gem.authors    = ['Daniel J. Berger', 'Park Heesob']
   gem.license    = 'Artistic 2.0'
   gem.email      = 'djberg96@gmail.com'
   gem.homepage   = 'http://www.rubyforge.org/projects/win32utils'
   gem.platform   = Gem::Platform::RUBY
   gem.summary    = 'Interface for the MS Windows Event Log.'
   gem.test_files = Dir['test/*.rb']
   gem.has_rdoc   = true
   gem.files      = Dir['**/*'].reject{ |f| f.include?('CVS') }

   gem.rubyforge_project = 'win32utils'
   gem.extra_rdoc_files  = ['README', 'CHANGES', 'MANIFEST', 'doc/tutorial.txt']

   gem.add_dependency('windows-pr', '>= 0.9.3')
   gem.add_development_dependency('ptools', '>= 1.1.6')
   gem.add_development_dependency('test-unit', '>= 2.0.3')

   gem.description = <<-EOF
      The win32-eventlog library provides an interface to the MS Windows event
      log. Event logging provides a standard, centralized way for applications
      (and the operating system) to record important software and hardware
      events. The event-logging service stores events from various sources in a
      single collection called an event log. This library allows you to inspect
      existing logs as well as create new ones.
   EOF
end

Gem::Builder.new(spec).build
