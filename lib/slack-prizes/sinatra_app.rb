require 'sinatra'
require 'tilt/erb'

module SlackPrizes
  class SinatraApp < Sinatra::Base
    def self.redis; @redis; end
    def self.redis=(redis); @redis = redis; end

    def self.resolve_channel(channel_id)
      @redis.hget(:channels, channel_id)
    end

    def self.resolve_user(user_id)
      @redis.hget(:users, user_id)
    end

    def self.highest_user_from_zset(set)
      user_id, score = SinatraApp.redis.zrange(set, -1, -1, withscores: true).first
      if user_id
        "#{resolve_user(user_id)} (#{score.to_i})"
      else
        "Unknown"
      end
    end

    def self.highest_pair_from_zset(set)
      user_ids, score = SinatraApp.redis.zrange(set, -1, -1, withscores: true).first
      if user_ids
        ids = user_ids.split(' ')
        users = ids.map { |id| resolve_user(id) }
        "#{users[0]} & #{users[1]} (#{score.to_i})"
      else
        "Unknown"
      end
    end

    def self.lowest_user_from_zset(set)
      user_id, score = SinatraApp.redis.zrevrange(set, -1, -1, withscores: true).first
      if user_id
        "#{resolve_user(user_id)} (#{score.to_i})"
      else
        "Unknown"
      end
    end

    def self.get_graph(set, limit)
      @redis.zrange(set, 0, limit - 1, withscores: true).map do |user_id, score|
        { label: resolve_user(user_id), value: score }
      end
    end

    set :public_folder, File.dirname(__FILE__) + '/static'

    CATEGORIES = [
      {
        name: '&#128588; GG',
        find: lambda { SinatraApp.highest_user_from_zset(:gg) }
      },
      {
        name: '&#128515; Happy',
        find: lambda { SinatraApp.highest_user_from_zset(:happy) }
      },
      {
        name: '&#127865; Helpful',
        find: lambda { SinatraApp.highest_user_from_zset(:thanks) }
      },
      {
        name: '&#128561; Emoji',
        find: lambda { SinatraApp.highest_user_from_zset(:emoji) }
      },
      {
        name: '&#128123; Spammer',
        find: lambda { SinatraApp.highest_user_from_zset(:spammer) }
      },
      {
        name: '&#128040; Quiet',
        find: lambda { SinatraApp.lowest_user_from_zset(:spammer) }
      },
      {
        name: '&#128129; Popular',
        find: lambda { SinatraApp.highest_user_from_zset(:popular) }
      },
      {
        name: '&#128145; Lovebirds',
        find: lambda {
          user_ids, score = SinatraApp.redis.zrange(:lovebirds, -1, -1, withscores: true).first
          if user_ids
            ids = user_ids.split(' ')
            users = ids.map { |id| resolve_user(id) }
            channel = resolve_channel(SinatraApp.redis.hget('lovebirds:channel', user_ids))
            time = Time.at(SinatraApp.redis.hget('lovebirds:ts', user_ids).to_i).strftime('%a %e %b %H:%M')

            "#{users[0]} & #{users[1]} (#{score.to_i} messages in ##{channel} on #{time})"
          else
            "Unknown"
          end
        }
      }
    ]

    get '/' do
      @data = CATEGORIES
      @graph_data = {
        spammer: SinatraApp.get_graph(:spammer, 10),
        popular: SinatraApp.get_graph(:popular, 10)
      }
      erb :index
    end
  end
end
