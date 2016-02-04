require 'spec_helper'

describe SlackPrizes::UsefulRegistry do
  let(:redis) { double('redis') }

  subject {
    SlackPrizes::UsefulRegistry.new(redis: redis)
  }

  describe "Last speaker by channel" do
    before :each do
      allow(redis).to receive(:hset).with('users', anything, anything)
    end

    it 'Should return the last speaker seen' do
      subject.scan({
        'user_id' => 'uid',
        'channel_id' => 'cid'
      })

      expect(subject.last_speaker('cid')).to eq('uid')
    end

    it 'Should return the last speaker seen with an exclusion' do
      subject.scan({
        'user_id' => 'uid1',
        'channel_id' => 'cid'
      })

      subject.scan({
        'user_id' => 'uid2',
        'channel_id' => 'cid'
      })

      expect(subject.last_speaker('cid')).to eq('uid2')
      expect(subject.last_speaker('cid', 'uid2')).to eq('uid1')
    end
  end
end
