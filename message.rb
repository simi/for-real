#!/bin/env ruby

require 'bundler/setup'
require 'amqp'
require 'json'

text = ARGV.join(" ")
message = {
  type: 'server',
  message: "SERVER: #{text}",
}.to_json

AMQP.start do |connection|
  AMQP::Channel.new(connection) do |channel|
    mq = channel.fanout('test')
    mq.publish(message)
    connection.close {EM.stop}
  end
end
