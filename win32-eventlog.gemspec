Gem::Specification.new do |spec|
  spec.name       = 'win32-eventlog'
  spec.version    = '0.6.7'
  spec.authors    = ['Daniel J. Berger', 'Park Heesob']
  spec.license    = 'Artistic 2.0'
  spec.email      = 'djberg96@gmail.com'
  spec.homepage   = 'http://github.com/chef/win32-eventlog'
  spec.summary    = 'Interface for the MS Windows Event Log.'
  spec.test_files = Dir['test/*.rb']
  spec.files      = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(\..*|Gemfile|Rakefile|doc|examples|VERSION|appveyor.yml|test|spec)}) }

  spec.extra_rdoc_files  = ['README.md', 'CHANGELOG.md', 'doc/tutorial.txt']

  spec.add_dependency('ffi')

  spec.description = <<-EOF
    The win32-eventlog library provides an interface to the MS Windows event
    log. Event logging provides a standard, centralized way for applications
    (and the operating system) to record important software and hardware
    events. The event-logging service stores events from various sources in a
    single collection called an event log. This library allows you to inspect
    existing logs as well as create new ones.
  EOF
end
