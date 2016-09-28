require 'sinatra'
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
        :Host            => "0.0.0.0",
        :Port            => 443,
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
  $mutable_haproxy_config = $haproxy_config + '.haproxy-api.json'
  
  #before do
  #  request.body.rewind
  #  if request.body.size > 0
  #    @request_payload = JSON.parse request.body.read
  #  end
  #end  


  def get_config
    return { 'frontend' => {}, 'backend' => {} } if !File.exists?($mutable_haproxy_config)
    return JSON.parse(File.read($mutable_haproxy_config))
  end
    

  def render(config)
    content = ""
    f = File.open($haproxy_config, "r")
    in_gen_section = false
    f.each_line do |line|
      if line =~ /HAPROXY_API_GENERATED/
        if in_gen_section 
          in_gen_section = false
        else
          in_gen_section = true          
        end
      else
        if !in_gen_section
           content += line
        end       
      end      
    end
    f.close

    content += "# HAPROXY_API_GENERATED - START\n"
    
    config['frontend'].each_pair do |name, frontend|
      content += "frontend #{name}\n"
      content += "  bind 0.0.0.0:#{frontend['port']}\n"
      content += "  default_backend #{name}-backend\n"
      content += "\n"
    end

    config['backend'].each_pair do |name, backend|
      content += "backend #{name}\n"
      content += "  balance #{backend['lbmethod']}\n"
      
      if backend.has_key?('options')
        backend['options'].each_pair do |k,v|
          content += "  option #{k} #{v}\n"
        end
      end
      
      port = backend['port']
      server_options = ""
      if backend.has_key?('server_options')
        backend['server_options'].each_pair do |k,v|
          server_options += "#{k} #{v} "
        end
      end

      backend['servers'].each do |server|
        content += "  server #{server}:#{port} #{server}:#{port} #{server_options} \n"      
      end
      content += "\n"        
    end

    content += "# HAPROXY_API_GENERATED - END\n"
          
    return content
  end
  
  
  def set_config(config)
    ts = Time.now.to_i
    `cp #{$haproxy_config} #{$haproxy_config}.#{ts}`
    content = render config
    File.open($mutable_haproxy_config, 'w') { |file| file.write(JSON.dump(config)) }
    File.open($haproxy_config, 'w') { |file| file.write(content) }        
    
    result = `/usr/sbin/haproxy -c -f #{$haproxy_config}`
    if $?.to_i == 0
      puts `systemctl restart haproxy`
    else
      puts "rolling back config - got:"
      puts result
      `cp #{$haproxy_config}.#{ts} #{$haproxy_config}`
      return status(500)
    end
  end

  get '/render' do
    config = get_config
    render config
  end  
      
  get '/frontends' do
    config = get_config
    JSON.dump(config['frontend'])
  end
  
  get '/frontend/:id' do
    config = get_config
    id = params[:id]
    return status(404) if !config['frontend'].has_key?(id)
    JSON.dump(config['frontend'][id])
  end

  post '/frontend/:id' do
    config = get_config
    
    id = params[:id]
    if config['frontend'].has_key?(id)
      puts "#{id} already exists - use put"
      return status(500)
    end

    frontend = JSON.parse request.body.read
    config['frontend'][id] = frontend
    set_config config
    JSON.dump(frontend)
  end 

  delete '/frontend/:id' do
    config = get_config
    config['frontend'].delete params[:id]
    set_config config
  end
    
      
  get '/backends' do
    config = get_config
    JSON.dump(config['backend'])
  end


  get '/backend/:id' do
    config = get_config
    id = params[:id] + "-backend"
    return status(404) if !config['backend'].has_key?(id)
    JSON.dump(config['backend'][id])
  end


  post '/backend/:id' do
    config = get_config
    id = params[:id] + "-backend"
    if config['backend'].has_key?(id)
      puts "#{id} already exists - use put"
      return status(500)
    end
    backend = JSON.parse request.body.read
    config['backend'][id] = backend
    set_config config
    JSON.dump(backend)
  end
   
  
  delete '/backend/:id' do
    config = get_config
    config['backend'].delete(params[:id] + "-backend")
    set_config config
  end

end

Rack::Handler::WEBrick.run HaproxyApi, webrick_options

