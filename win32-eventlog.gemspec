require 'rubygems'

Gem::Specification.new do |spec|
  spec.name       = 'win32-eventlog'
  spec.version    = '0.5.3'
  spec.authors    = ['Daniel J. Berger', 'Park Heesob']
  spec.license    = 'Artistic 2.0'
  spec.email      = 'djberg96@gmail.com'
  spec.homepage   = 'http://www.rubyforge.org/projects/win32utils'
  spec.summary    = 'Interface for the MS Windows Event Log.'
  spec.test_files = Dir['test/*.rb']
  spec.files      = Dir['**/*'].reject{ |f| f.include?('git') }

  spec.rubyforge_project = 'win32utils'
  spec.extra_rdoc_files  = ['README', 'CHANGES', 'MANIFEST', 'doc/tutorial.txt']

  spec.add_dependency('windows-pr', '>= 0.9.3')
  spec.add_development_dependency('ptools', '>= 1.1.6')
  spec.add_development_dependency('test-unit', '>= 2.1.1')

  spec.description = <<-EOF
    The win32-eventlog library provides an interface to the MS Windows event
    log. Event logging provides a standard, centralized way for applications
    (and the operating system) to record important software and hardware
    events. The event-logging service stores events from various sources in a
    single collection called an event log. This library allows you to inspect
    existing logs as well as create new ones.
  EOF
end
