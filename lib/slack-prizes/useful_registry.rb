module SlackPrizes
  class UsefulRegistry
    def initialize
      @last_message_by_channel = {}
      @last_speakers_by_channel = Hash.new { |h, k| h[k] = HistoryVector.new(2) }
    end

    def scan(data)
      @last_message_by_channel[data.channel] = data

      @last_speakers_by_channel[data.channel].add(data.user)
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
