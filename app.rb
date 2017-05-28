require 'sinatra'
require 'intercom'
require 'dotenv'
require 'sinatra/activerecord'
require './models/mapping'
require './models/user_mapping'
require './models/ignore_webhook'
require 'httparty'
require "reverse_markdown"
require 'slack-notifier'

Dotenv.load

DEBUG = ENV["DEBUG"] || nil

##############################################################################
# Create User Mapping of Slack ID to Intercom ID
##############################################################################
# Allows replies in Slack to be sent to Intercom
# UserMapping.create({slack_user_id: "U02JGGQR6", intercom_admin_id: 248698})
##############################################################################

get '/5' do    
  sleep 5
  return 200, "5 #{DateTime.now}"
end
get '/1' do    
  return 200, "1 #{DateTime.now}"
end
get '/init' do
  UserMapping.create({slack_user_id: "U02JGGQR6", intercom_admin_id: 248698})
  return 200, "1 #{DateTime.now}"
end

# Process Slack data
post '/' do
  request.body.rewind
  payload_body = request.body.read

  puts "== Slack Webhook payload ======================================"
  puts payload_body
  puts "==============================================================="
  begin
    verify_signature(payload_body)
    data = JSON.parse(payload_body)
    puts "Topic Recieved: #{data['topic']}"
    if data["type"] == "url_verification"
      return data["challenge"];
    elsif data["type"] == "event_callback" && data["event"]["type"] == "message" && data["event"]["thread_ts"]
      puts "Check if should send? Sleep to see if that allows processing";
      sleep(3)
      mapping = Mapping.where(:slack_ts_id => data["event"]["thread_ts"]).first
      if mapping.nil? or mapping.intercom_convo_id.nil?
        puts "No mapping data can't send"
      else
        user_mapping = UserMapping.where(:slack_user_id => data["event"]["user"]).first
        if user_mapping.nil? or user_mapping.intercom_admin_id.nil?
          puts "No user mapping data"
        else
          puts "Send to Intercom!";
          init_intercom
          response = @intercom.conversations.reply(id: mapping.intercom_convo_id, type: 'admin', admin_id: user_mapping.intercom_admin_id, message_type: 'comment', body: data["event"]["text"])
          puts "API response: convo_id: #{response.id} coment_id: #{response.conversation_parts.last.id}"
          IgnoreWebhook.create({intercom_convo_id: response.id, intercom_comment_id: response.conversation_parts.last.id})
        end
      end
    end
  rescue => e
    puts "Payload not JSON formatted"
    puts e.inspect
    puts e.backtrace
  end
end



post '/intercom' do
  request.body.rewind
  payload_body = request.body.read

  puts "== Intercom Webhook payload ==================================="
  puts payload_body
  puts "==============================================================="
  begin
    data = JSON.parse(payload_body)
    verify_signature(payload_body)
    puts "Topic Recieved: #{data['topic']}"
    processWebhook(data)
  rescue => e
    puts "Payload not JSON formatted"
    puts e.inspect
    puts e.backtrace
  end
end

def processWebhook(data)
  topic = data["topic"]
  if topic == "conversation.user.created" || 
    topic == "conversation.user.replied" || 
    topic == "conversation.admin.single.created"  || 
    topic == "conversation.admin.replied" || 
    topic == "conversation.admin.assigned" || 
    topic == "conversation.admin.closed" || 
    topic == "conversation.admin.opened" || 
    topic == "conversation.admin.noted"
    processToSlack(data)
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

def formatUserDisplayName(user)
  "#{user['name'] || user['user_id'] || ['user.email']} (#{user['type']})"
end

def processToSlack(raw_data)
  # puts "processToSlack raw #{raw_data.inspect}"
  user_reply = (raw_data["topic"] == "conversation.user.replied" || raw_data["topic"] == "conversation.user.created")
  new_message = (raw_data["topic"] == "conversation.user.created" || raw_data["topic"] == "conversation.admin.single.created")
  app_id = raw_data["app_id"];
  data = raw_data["data"]
  conversation = data["item"]
  current_assignee = data["item"]["assignee"]
  user = data["item"]["user"]
  message = data["item"]["conversation_message"]
  part = data["item"]["conversation_parts"]["conversation_parts"][0] if data["item"]["conversation_parts"] && data["item"]["conversation_parts"]["conversation_parts"]
  admin = part["author"] if part
  admin = current_assignee if new_message && !user_reply
  opened = part["part_type"] == "open" if part
  closed = part["part_type"] == "close" if part
  note = part["part_type"] == "note" if part
  assignment = part["part_type"] == "assignment" if part

  assignee = part["assigned_to"] if part
  link_to_convo = data["item"]["links"]["conversation_web"]

  user_link = "https://app.intercom.io/apps/#{app_id}/users/#{user['id']}"
  if new_message
    text_details_source = message
  else
    text_details_source = part
  end
  # puts text_details_source
  text_details=""
  if text_details_source
    raw_text = text_details_source['body']
    raw_markdown = ReverseMarkdown.convert(raw_text).gsub(/!\[\]\((.*)\)/,"\\1")
    slack_markdown = Slack::Notifier::Util::LinkFormatter.format(raw_markdown)

    text_details = " #{text_details}with text\n\n#{slack_markdown}\n" if text_details_source["body"]
    if text_details_source["attachments"].count > 0
      attachment_text = text_details_source['attachments'].map{|a|
        "-<#{a['url']}|#{a['name']}>"
      }.join("\n")
      text_details = "#{text_details}with attachments\n#{attachment_text}\n" 
    end
  end

  if user_reply

    if new_message
      text = "started"
    else
      text = "replied to"
    end
    output = "<#{user_link}|#{formatUserDisplayName(user)}> #{text} <#{link_to_convo}|conversation (#{conversation['id']})>#{text_details}"
    output_threaded = "<#{user_link}|#{formatUserDisplayName(user)}> #{text.gsub(/ to$/,'')}#{text_details}"

  else
    text = "replied to"
    text = "added a note to" if note
    text = "closed" if closed
    text = "opened" if opened
    text = "assigned" if assignment
    text = "created new" if new_message

    
    if assignee
      assignee_text = " and assigned to"
      assignee_text = " to" if assignee && assignment

      if assignee["type"] == "nobody_admin"
        assigned_name = "Nobody / Unassigned"
      else
        assigned_name = "#{assignee['name']}"
        assigned_name = "themselves" if admin['id'] == assignee['id']
        #assigned_name = "#{assigned_name} (#{assignee['id']})"
        link_to_admin = "https://app.intercom.io/a/apps/#{app_id}/admins/#{assignee['id']}"
        assigned_name = "<#{link_to_admin}|#{assigned_name}>"
        
      end
      assignee_text = " #{assignee_text} #{assigned_name}"
    end

    admin_text = "Unknown admin"
    admin_text = "#{admin['name']} (#{admin['id']})" if admin

    conversation_details = ""
    conversation_details = " with <#{user_link}|#{formatUserDisplayName(user)}>" if user

    output = "#{admin_text} #{text} <#{link_to_convo}|conversation (#{conversation['id']})>#{conversation_details}#{assignee_text}#{text_details}"
    output_threaded = "#{admin_text} #{text.gsub(/ to$/,'')} #{assignee_text}#{text_details}"
  end
  convo_id = conversation["id"];

  mapping = Mapping.where(:intercom_convo_id => convo_id).first
  slack_thread_id = nil
  slack_thread_id = mapping.slack_ts_id if mapping

  if part
    puts "convo: #{convo_id} comment: #{part["id"]}"
    ignore = IgnoreWebhook.where(:intercom_convo_id => convo_id,:intercom_comment_id => part["id"]).first
  end
  puts "Ignore DB data: #{ignore}"
  if ignore
    puts "Ignore webhook as message was sent from Slack!"
  else
    puts "Not from slack Send notification to Slack"
    response = postToSlack(slack_thread_id ? output_threaded : output, slack_thread_id, {
      text_details: text_details,
      reply_type: {
        user_reply: user_reply,
        note: note,
        closed: closed,
        opened: opened,
        assignment: assignment,
        new_message: new_message,
      }
    })
    slack_ts_id = response["ts"]
    puts "Response from Slack #{response}"
    Mapping.create({intercom_convo_id: convo_id, slack_ts_id: slack_ts_id}) if !mapping
  end
end
def getColour (reply_type)
    puts reply_type
    if reply_type[:user_reply]
      return "#0073B0"
    else
      return "#EC8B23"
    end
end
def getEmoji(reply_type)
    if reply_type[:user_reply]
      return ":envelope_with_arrow:"
    elsif reply_type[:opened]
      return ":arrow_heading_up:"
    elsif reply_type[:closed]
      return ":white_check_mark:"
    elsif reply_type[:assignment]
      return ":clipboard:"
    elsif reply_type[:note]
      return ":memo:"
    else
      return ":rocket:"
    end
end
def postToSlack (text, thread_ts, data)
  #puts data
  options = {
    headers: {"Content-Type" => "application/x-www-form-urlencoded"},
    body: {
      token: ENV["SLACK_TOKEN"],
      channel: ENV["SLACK_CHANNEL"],
      icon_emoji: getEmoji(data[:reply_type]),
      # attachments: [{
      #   color: getColour(data[:reply_type]),
      #   text: text
      # }].to_json,
      text: text,
      unfurl_media: true
    }
  }
  options[:body][:thread_ts] = thread_ts if thread_ts
  #puts options
  response = HTTParty.post('https://slack.com/api/chat.postMessage', options)  
  #puts response
end
def init_intercom
  if @intercom.nil? then
    token = ENV["TOKEN"]
    @intercom = Intercom::Client.new(token: token)
  end
end
