$:.unshift File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = 'haproxy-api'
  s.version     = '0.1.3'
  s.license     = 'Apache-2.0'
  s.author      = 'Mike Schwankl'
  s.email       = 'schwankl@gmail.com'
  s.homepage    = 'https://github.com/schwankl/haproxy-api'
  s.description = 'Haproxy API using sinatra'
  s.summary     = 'rest API using to haproxy'
  s.executables = %w(hapi install_haproxy-api_initd)
  s.platform         = Gem::Platform::RUBY
  s.extra_rdoc_files = %w()
  s.add_dependency('sinatra', '1.4.7')
  s.add_dependency('webrick', '1.3.1')

  s.require_path = 'lib'
  s.files        = %w() + ["haproxy-api.gemspec"] +  Dir.glob("lib/**/*") + Dir.glob('bin/**/*')
end
