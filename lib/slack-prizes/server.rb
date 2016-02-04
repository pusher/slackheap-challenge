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
      check_emoji(data)
      check_thanks(data)
      check_gg(data)
    end

    HAPPY_REGEXES = [
      /:[^:]*smile:/,
      /:\)/,
      /:D/,
      /:-\)/,
      /:-D/
    ]

    def check_happy(data)
      check_and_count(data, HAPPY_REGEXES, :happy)
    end

    EMOJI_REGEXES = [
      /:[a-z_]+:/i
    ]

    def check_emoji(data)
      check_and_count(data, EMOJI_REGEXES, :emoji)
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
      check_and_attribute(data, THANKYOU_REGEXES, :thanks)
    end

    GG_REGEXES = [
      /\bgg\b/i,
      /:gg:/i
    ]

    def check_gg(data)
      check_and_attribute(data, GG_REGEXES, :gg)
    end

    def check_and_count(data, regexes, key)
      if match_any(regexes, data['text'])
        @redis.zincrby(key, 1, data['user_id'])
      end
    end

    def check_and_attribute(data, regexes, key)
      if match_any(regexes, data['text'])
        target = mention(data['text']) || @registry.last_speaker(data['channel_id'], data['user_id'])
        if target
          @redis.zincrby(key, 1, target)
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
