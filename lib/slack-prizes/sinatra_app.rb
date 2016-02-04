require 'sinatra'

module SlackPrizes
  class SinatraApp < Sinatra::Base
    post '/in' do
      Server.queue.push params
      'OK'
    end
  end
end
