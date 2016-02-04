module SlackPrizes
  class UsefulRegistry
    def initialize(redis: nil)
      @redis = redis

      @last_message_by_channel = {}
      @last_speakers_by_channel = Hash.new { |h, k| h[k] = HistoryVector.new(2) }
      @known_users = Set.new
    end

    def scan(data)
      @last_message_by_channel[data['channel_id']] = data

      @last_speakers_by_channel[data['channel_id']].add(data['user_id'])

      unless @known_users.member?(data['user_id'])
        @redis.hset('users', data['user_id'], data['user_name'])
        @known_users.add(data['user_id'])
      end
    end

    def last_speaker(channel_id, excluding = nil)
      if excluding
        @last_speakers_by_channel[channel_id].peek_excluding(excluding)
      else
        @last_speakers_by_channel[channel_id].peek
      end
    end
  end
end
