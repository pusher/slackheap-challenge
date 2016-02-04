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
      redis: nil
    )
      @thin_server = thin_server
      @redis = redis

      @last_message_by_channel = {}
      @last_speakers_by_channel = Hash.new { |h, k| h[k] = HistoryVector.new(2) }
      @known_users = Set.new
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
      register(data)

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
      /[^\p{Alnum}]ty[^\p{Alnum}]/i,
      /[^\p{Alnum}]ta[^\p{Alnum}]/i,
      /thx/i,
      /cheers/i
    ]

    def check_thanks(data)
      if match_any(THANKYOU_REGEXES, data['text'])
        target = mention(data['text']) || last_speaker(data)
        if target
          @redis.zincrby(:thanks, 1, target)
        end
      end
    end

    def last_speaker(channel_id, excluding = nil)
      speakers = @last_speakers_by_channel['channel_id']
      if excluding
        speakers.peek_excluding(excluding)
      else
        speakers.peek
      end
    end

    def mention(words)
      if words =~ /<@([^>]+)>/
        return $1
      else
        nil
      end
    end

    def register(data)
      @last_message_by_channel[data['channel_id']] = data

      @last_speakers_by_channel[data['channel_id']].add(data['user_id'])

      unless @known_users.member?(data['user_id'])
        @redis.hset('users', data['user_id'], data['user_name'])
        @known_users.add(data['user_id'])
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
