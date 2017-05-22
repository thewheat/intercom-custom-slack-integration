require 'sinatra'
require 'intercom'
require 'dotenv'

Dotenv.load

DEBUG = ENV["DEBUG"] || nil
BULK_LIMIT = 50

# Ruby http://arcane-plateau-46442.herokuapp.com/ 
# PHP http://polar-cliffs-15537.herokuapp.com/slack.php
post '/' do
  request.body.rewind
  payload_body = request.body.read
  puts "==============================================================="
  puts payload_body
  puts "==============================================================="
  data = JSON.parse(payload_body)
  data["type"]
  if data["type"] == "url_verification"
    return data["challenge"];
  elsif data["type"] == "event_callback" && data["event"]["type"] == "message" && data["event"]["thread_ts"]
    echo "Send to Intercom!";
  end

  verify_signature(payload_body)
  puts "Topic Recieved: #{data['topic']}"
end

def verify_signature(payload_body)
  secret = "secret"
  expected = request.env['HTTP_X_HUB_SIGNATURE']
  if expected.nil? || expected.empty? then
    puts "Not signed. Not calculating"
  else
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, payload_body)
    puts "Expected  : #{expected}"
    puts "Calculated: #{signature}"
    if Rack::Utils.secure_compare(signature, expected) then
      puts "   Match"
    else
      puts "   MISMATCH!!!!!!!"
      return halt 500, "Signatures didn't match!"
    end
  end
end


def init_intercom
  if @intercom.nil? then
    app_id = ENV["APP_ID"]
    api_key = ""
    api_key = ENV["API_KEY"] if (!ENV["API_KEY"].nil? && ENV["API_KEY"])
    @intercom = Intercom::Client.new(app_id: app_id, api_key: api_key)
  end
end

