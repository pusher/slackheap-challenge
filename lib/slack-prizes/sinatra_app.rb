require 'sinatra'

module SlackPrizes
  class SinatraApp < Sinatra::Base
    def self.redis; @redis; end
    def self.redis=(redis); @redis = redis; end

    def self.resolve_user(user_id)
      @redis.hget(:users, user_id)
    end

    def self.best_user_from_zset(set)
      user_id = SinatraApp.redis.zrange(set, -1, -1).first
      if user_id
        resolve_user(user_id)
      else
        "Unknown"
      end
    end

    set :public_folder, File.dirname(__FILE__) + '/static'

    get '/' do
      @happiest = SinatraApp.best_user_from_zset(:happy)
      @most_helpful = SinatraApp.best_user_from_zset(:thanks)
      erb :index
    end

    post '/in' do
      Server.queue.push params
      'OK'
    end
  end
end
