require 'bundler/setup'

require 'em-websocket'
require 'uuid'
require 'amqp'
require 'json'

uuid = UUID.new

def current_time
  Time.now.strftime("%d/%m/%Y %H:%M:%S")
end


@clients = []

EventMachine::WebSocket.start(:host => "0.0.0.0", :port => 8080) do |ws|

  ws.onopen do
    puts "WebSocket opened"

    @nick = ws.request["query"]["nick"]
    @clients << @nick

    message = {
      type: 'userlist',
      message: "#{current_time} Connected ...",
      clients: @clients
    }.to_json
    ws.send message

    AMQP.connect do |connection|
      AMQP::Channel.new(connection) do |channel|
        message = {
          type: 'connected',
          nick: @nick,
          message: "#{current_time} #@nick connected"
        }.to_json

        channel.fanout('test').publish(message)
        channel.queue(uuid.generate, :auto_delete => true).bind(channel.fanout('test')).subscribe do |t|
          t.force_encoding('utf-8')
          ws.send t
        end
      end
    end
  end

  ws.onmessage do |message|
    @nick = ws.request["query"]["nick"]

    message = {
      type: 'message',
      message: "#{current_time} #{@nick}: #{message}"
    }.to_json

    AMQP.connect do |connection|
      AMQP::Channel.new(connection) do |channel|
        mq = channel.fanout('test')
        mq.publish(message)
      end
    end
  end

  ws.onclose do
    @nick = ws.request["query"]["nick"]
    @clients.delete(@nick)

    message = {
      type: 'disconnected',
      nick: @nick,
      message: "#{current_time} #@nick disconnected"
    }.to_json

    AMQP.connect do |connection|
      AMQP::Channel.new(connection) do |channel|
        mq = channel.fanout('test')
        mq.publish(message)
      end
    end
  end
end
