require 'sinatra'
require 'haproxy-tools'
require 'json'
require 'webrick'
require 'webrick/https'
require 'openssl'

CERT_PATH = ENV['CERT_PATH'] 

if CERT_PATH.nil? || !File.exists?(CERT_PATH+'/hapi.crt')
  puts "set CERT_PATH env var to where your hapi.crt and hapi.key are"
  exit 1 
end

webrick_options = {
        :Port            => 8443,
        :Logger          => WEBrick::Log::new($stderr, WEBrick::Log::DEBUG),
        :DocumentRoot    => "/ruby/htdocs",
        :SSLEnable       => true,
        :SSLVerifyClient => OpenSSL::SSL::VERIFY_NONE,
        :SSLCertificate  => OpenSSL::X509::Certificate.new(  File.open(File.join(CERT_PATH, "/hapi.crt")).read),
        :SSLPrivateKey   => OpenSSL::PKey::RSA.new(          File.open(File.join(CERT_PATH, "/hapi.key")).read),
        :SSLCertName     => [ [ "CN",WEBrick::Utils::getservername ] ]
}


class HaproxyApi < Sinatra::Base
  $haproxy_config = '/etc/haproxy/haproxy.cfg'
  if ENV['HAPROXY_CONFIG']
    $haproxy_config = ENV['HAPROXY_CONFIG']
  end

  #set :port, 8888

  #configure do
  #  enable :logging
  #  file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
  #  file.sync = true
  #  use Rack::CommonLogger, file
  #end

  def get_config
    return HAProxy::Config.parse_file($haproxy_config)
  end


  def set_config(config)
    ts = Time.now.to_i
    `cp #{$haproxy_config} #{$haproxy_config}.#{ts}`
    File.open($haproxy_config, 'w') { |f| f.puts config.render } 
    result = `systemctl restart haproxy`
    if $?.to_i != 0
      puts "rolling back config - got:"
      puts result
      `cp #{$haproxy_config}.ts #{$haproxy_config}`
      result = `systemctl restart haproxy`
    end
  end

      
  get '/frontends' do
    config = get_config
    JSON.dump(config.frontends)
  end


  get '/frontend/:id' do
    config = get_config
    return status 404 if config.frontend(params[:id]).nil?
    JSON.dump(config.frontend(params[:id]))
  end


  post '/frontend/:id' do
    config = get_config
    id = params[:id]
    if !config.frontend(id).nil?
      puts "already exists - use put"
      return status 500 if config.frontend(id).nil?
    end

    frontend = JSON.parse(params[:frontend])
    fe = HAProxy::Frontend.new :name => id,
     :port => frontend[:port],
     :options => {"http-server-close"=>nil}, :config => {"bind"=>"0.0.0.0:#{frontend[:port]}", "default"=>"_backend #{id}" }

    conifg.frontends.push fe
    set_config config
  end 


  delete '/frontend/:id' do
    config = get_config
    frontends = config.frontends.select { |fe| fe[:name] != params[:id] }
    config.frontends = frontends
    set_config config
  end
    
      
  get '/backends' do
    config = get_config
    JSON.dump(config.backends)
  end


  get '/backend/:id' do
    config = get_config
    return status 404 if config.backend(params[:id]).nil?
    JSON.dump(config.backend(params[:id]))
  end


  post '/backend/:id' do
    config = get_config
    id = params[:id]
    if !config.backend(id).nil?
      puts "already exists - use put"
      return status 500 if config.frontend(id).nil?
    end

    backend = JSON.parse(params[:backend])
    be = HAProxy::Backend.new :name => id, :config => {"balance"=>backend[:balance]}
    backend[:servers].each do |server|
      be.add_server("#{server}:#{backend[:port]}", server, :port => backend[:port] )
    end
    conifg.backends.push be
    set_config config
  end

  delete '/backend/:id' do
    config = get_config
    backends = config.backends.select { |be| be[:name] != params[:id] }
    config.backends = backends
    set_config config
  end

end

Rack::Handler::WEBrick.run HaproxyApi, webrick_options

