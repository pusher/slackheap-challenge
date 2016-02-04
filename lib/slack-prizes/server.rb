require 'thin'
require 'redis'
require 'thread'
require 'set'

module SlackPrizes
  class Server
    def self.queue
      @queue ||= Queue.new
    end

    def initialize(
      thin_server: nil,
      redis: nil,
      registry: nil
    )

      @thin_server = thin_server
      @redis = redis
      @registry = registry
    end

    def go
      Thread.new {
        @thin_server.start
      }

      while true
        process(Server.queue.pop)
      end
    end

    def process(data)
      p data
      @registry.scan(data)

      check_happy(data)
      check_thanks(data)
    end

    HAPPY_REGEXES = [
      /:[^:]*smile:/,
      /:\)/,
      /:D/,
      /:-\)/,
      /:-D/
    ]

    def check_happy(data)
      if match_any(HAPPY_REGEXES, data['text'])
        @redis.zincrby(:happy, 1, data['user_id'])
      end
    end

    THANKYOU_REGEXES = [
      /thanks/i,
      /thank you/i,
      /\bty\b/i,
      /\bta\b/i,
      /thx/i,
      /cheers/i
    ]

    def check_thanks(data)
      if match_any(THANKYOU_REGEXES, data['text'])
        target = mention(data['text']) || @registry.last_speaker(data['channel_id'], data['user_id'])
        if target
          @redis.zincrby(:thanks, 1, target)
        end
      end
    end

    def mention(words)
      if words =~ /<@([^>]+)>/
        return $1
      else
        nil
      end
    end

    def match_any(regexs, words)
      regexs.each { |r|
        if words =~ r
          return true
        end
      }
      false
    end
  end
end
