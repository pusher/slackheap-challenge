require 'spec_helper'

describe SlackPrizes::Server do

  let(:redis) { double('redis') }
  let(:registry) { instance_double(SlackPrizes::UsefulRegistry) }
  let(:uid) { 'user52CD' }
  let(:other_uid) { 'user12AF' }
  let(:cid) { 'chan453w' }

  def with_text(words, merge = {})
    {
      'user_id' => uid,
      'channel_id' => cid,
      'text' => words
    }.merge(merge)
  end

  subject {
    SlackPrizes::Server.new(
      redis: redis,
      registry: registry
    )
  }

  describe 'Happy' do
    it 'should increment on ":)"' do
      expect(redis).to receive(:zincrby).with(:happy, 1, uid)

      subject.check_happy(with_text("I'm happy :)"))
    end
  end

  describe 'Thanks' do
    it 'should increment last speaker on "ty dude"' do
      expect(registry).to receive(:last_speaker).with(cid, uid).and_return(other_uid)
      expect(redis).to receive(:zincrby).with(:thanks, 1, other_uid)

      subject.check_thanks(with_text("ty dude"))
    end

    it 'should increment last speaker on "TY DUDE"' do
      expect(registry).to receive(:last_speaker).with(cid, uid).and_return(other_uid)
      expect(redis).to receive(:zincrby).with(:thanks, 1, other_uid)

      subject.check_thanks(with_text("TY DUDE"))
    end

    it 'should increment mentioned user on "thanks @user"' do
      expect(redis).to receive(:zincrby).with(:thanks, 1, other_uid)

      subject.check_thanks(with_text("thanks <@#{other_uid}>"))
    end

    it 'should not increment on "safety"' do
      subject.check_thanks(with_text("safety"))
    end

    it 'should not increment on "SAFETY"' do
      subject.check_thanks(with_text("SAFETY"))
    end
  end

  describe "Lovebirds" do
    it 'should count messages exchanged between two people' do
      expect(redis).to receive(:zincrby).with(:lovebirds, 1, "#{other_uid} #{uid}")

      subject.check_lovebirds(with_text('blah'))
      subject.check_lovebirds(with_text('blah', 'user_id' => other_uid))
    end
  end
end
