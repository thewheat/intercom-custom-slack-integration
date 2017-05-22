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

  puts "== method ======================================================"
  puts request.request_method
  puts "== GET ========================================================="
  puts request.env["QUERY_STRING"] if request.env["QUERY_STRING"]
 # puts JSON.pretty_generate(request.env["rack.request.query_hash"]) rescue nil
 # puts "== POST ======================================================="
 # puts JSON.pretty_generate(request.env["rack.request.form_hash"]) rescue nil
 # puts "== request body    ============================================"
#  puts request.body
  puts "== PARAMS ====================================================="
  puts params.inspect
  puts "== Webhook payload ============================================"
  puts payload_body
  puts "==============================================================="
  begin
    data = JSON.parse(payload_body)
    data["type"]
    if data["type"] == "url_verification"
      return data["challenge"];
    elsif data["type"] == "event_callback" && data["event"]["type"] == "message" && data["event"]["thread_ts"]
      puts "Send to Intercom!";
    end

    verify_signature(payload_body)
    puts "Topic Recieved: #{data['topic']}"
  rescue
    puts "Payload not JSON formatted"
  end
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

