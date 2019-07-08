require 'singleton'

module Sevak
  class Publisher
    include Core
    include Singleton

    def self.publish(queue_name, message)
      attempt = 0
      begin
        instance.queue(queue_name).publish(message.to_json)
      rescue => e #Bunny::ConnectionClosedError => e
        attempt += 1
        sleep(0.001)
        attempt < 2 ? retry : raise
      end
    end

    def self.delayed_publish(queue_name, message, delay = 0)
      attempt = 0
      begin
        instance.publish_exchange(queue_name, message, delay.to_i)
      rescue => e #Bunny::ConnectionClosedError => e
        attempt += 1
        sleep(0.001)
        attempt < 2 ? retry : raise 
      end
    end

    def channel
      (@channel && @channel.open?)? @channel : (@channel = connection.create_channel)
    end

    def queue(queue_name)
      channel.queue(queue_name, durable: true)
    end

    def exchange(queue_name)
      channel.exchange("#{queue_name}_exchange", type: 'x-delayed-message', durable: true, arguments: { 'x-delayed-type' => 'direct' })
    end

    def publish_exchange(queue_name, message, delay)
      queue(queue_name).bind(exchange(queue_name))
      exchange(queue_name).publish(message.to_json, headers: { 'x-delay' => delay })
    end
  end
end
