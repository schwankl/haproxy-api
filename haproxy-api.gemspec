$:.unshift File.expand_path("../lib", __FILE__)

require 'version'

Gem::Specification.new do |s|
  s.name        = 'haproxy-api'
  s.version     = '1.0.0'
  s.license     = 'Apache-2.0'
  s.author      = 'Mike Schwankl'
  s.description = 'Haproxy API using sinatra and haproxy-tools'
  s.summary     = 'Haproxy API using sinatra and haproxy-tools'
  s.executables = %(hapi)

  s.platform         = Gem::Platform::RUBY
  s.extra_rdoc_files = %w()
  s.add_dependency('sinatra', '1.4.7')
  s.add_dependency('haproxy-tools', '0.4.2')
  s.add_dependency('webrick', '1.3.1')

  s.bindir       = 'bin'
  s.require_path = 'lib'
  s.files        = %w() + ["haproxy-api.gemspec"] +  Dir.glob("lib/**/*") + Dir.glob('bin/**/*')
end
