require 'slack-ruby-client'
require 'thin'
require 'redis'
require 'thread'
require 'set'

module SlackPrizes
  class Server
    def initialize(
      redis: nil,
      registry: nil
    )
      @redis = redis
      @registry = registry
    end

    def go
      client = Slack::RealTime::Client.new(token: ENV['SLACK_TOKEN'])

      client.on :hello do
        puts "Successfully connected, welcome '#{client.self.name}' to the '#{client.team.name}' team at https://#{client.team.domain}.slack.com."
        client.users.each do |user|
          user = user[1] # slightly odd data: [ user_id, user_object ]
          @redis.hset(:users, user.id, user.name)
        end
      end

      client.on :message do |data|
        process(data)
      end

      client.start!
    end

    def process(data)
      @registry.scan(data)

      check_happy(data)
      check_emoji(data)
      check_thanks(data)
      check_gg(data)
      check_spammer(data)
      check_popular(data)
      check_lovebirds(data)
    end

    def check_spammer(data)
      check_and_count(data, [//], :spammer)
    end

    def check_lovebirds(data)
      user_a = data.user
      user_b = @registry.last_speaker(data.channel, user_a)
      if user_b
        users = [ user_a, user_b ].sort.join(' ')
        @redis.zincrby(:lovebirds, 1, users)
      end
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

    def check_emoji(data)
      check_and_count(data, [ /:[a-z_]+:/i ], :emoji)
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

    def check_popular(data)
      target = mention(data.text)
      if target
        @redis.zincrby(:popular, 1, target)
      end
    end

    def check_and_count(data, regexes, key)
      if match_any(regexes, data.text)
        @redis.zincrby(key, 1, data.user)
      end
    end

    def check_and_attribute(data, regexes, key)
      if match_any(regexes, data.text)
        target = mention(data.text) || @registry.last_speaker(data.channel, data.user)
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
