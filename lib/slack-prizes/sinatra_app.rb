require 'sinatra'

module SlackPrizes
  class SinatraApp < Sinatra::Base
    def self.redis; @redis; end
    def self.redis=(redis); @redis = redis; end

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

    def self.lowest_user_from_zset(set)
      user_id, score = SinatraApp.redis.zrevrange(set, -1, -1, withscores: true).first
      if user_id
        "#{resolve_user(user_id)} (#{score.to_i})"
      else
        "Unknown"
      end
    end

    set :public_folder, File.dirname(__FILE__) + '/static'

    get '/' do
      data = [ :happy, :thanks, :gg, :emoji, :spammer, :popular ].map do |type|
        [ type, SinatraApp.highest_user_from_zset(type) ]
      end
      @data = Hash[data]
      @data[:quiet] = SinatraApp.lowest_user_from_zset(:spammer)

      erb :index
    end

    post '/in' do
      Server.queue.push params
      'OK'
    end
  end
end
