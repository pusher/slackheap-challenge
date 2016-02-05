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
      @client = Slack::RealTime::Client.new(token: ENV['SLACK_TOKEN'])

      @client.on :hello do
        puts "Successfully connected, welcome '#{@client.self.name}' to the '#{@client.team.name}' team at https://#{@client.team.domain}.slack.com."
        @client.users.each_value do |user|
          @redis.hset(:users, user.id, user.name)
        end

        @client.channels.each_value do |channel|
          @redis.hset(:channels, channel.id, channel.name)
        end
      end

      @client.on :message do |data|
        begin
          process(data)
        rescue => e
          p e
        end
      end

      @client.start!
    end

    def process(data)
      check_happy(data)
      check_emoji(data)
      check_thanks(data)
      check_gg(data)
      check_spammer(data)
      check_popular(data)
      check_lovebirds(data)

      @registry.scan(data)
    end

    def check_spammer(data)
      check_and_count(data, [//], :spammer)
    end

    def check_lovebirds(data)
      user_a = data.user
      user_b = @registry.last_speaker(data.channel)

      # Ignore if user has double-spoken
      return if user_a == user_b

      if user_b
        users = [ user_a, user_b ].sort.join(' ')

        current_streakers = @redis.hget('streaks:users', data.channel)
        if users == current_streakers
          current_streak_length = @redis.hincrby('streaks:length', data.channel, 1)
          high_streak_length = @redis.zscore(:lovebirds, users)
          if high_streak_length.nil? || current_streak_length > high_streak_length
            @redis.zadd(:lovebirds, current_streak_length, users)
            @redis.hset('lovebirds:channel', users, data.channel)
            @redis.hset('lovebirds:ts', users, Time.now.to_i)
          end
        else
          @redis.hset('streaks:users', data.channel, users)
          @redis.hset('streaks:length', data.channel, 1)
        end
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
      if target &&
          target != data.user
        increment(:popular, 'popular', target, data.channel)
      end
    end

    def check_and_count(data, regexes, key)
      if match_any(regexes, data.text)
        increment(key, key.to_s, data.user, data.channel)
      end
    end

    def check_and_attribute(data, regexes, key)
      if match_any(regexes, data.text)
        target = mention(data.text) || @registry.last_speaker(data.channel, data.user)
        if target &&
            target != data.user
          increment(key, key.to_s, target, data.channel)
        end
      end
    end

    def increment(key, desc, user, channel)
      before_user, before_score = @redis.zrange(key, -1, -1, withscores: true).first
      after_score = @redis.zincrby(key, 1, user)

      if before_user &&
          before_user != user &&
          after_score.to_i == before_score.to_i
        @client.message(channel: channel, text: "<@#{user}> has taken the lead on #{desc} from <@#{before_user}> with #{after_score.to_i}!")
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
