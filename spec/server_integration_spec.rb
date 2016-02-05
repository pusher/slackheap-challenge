require 'spec_helper'

describe SlackPrizes::Server do

  let(:redis) { Redis.new(url: 'redis://localhost/14') }
  let(:registry) { SlackPrizes::UsefulRegistry.new }
  let(:uid_a) { 'user52CD' }
  let(:uid_b) { 'user12AF' }
  let(:uid_c) { 'user876A' }
  let(:cid_a) { 'chan453w' }
  let(:cid_b) { 'chanGH96' }

  Message = Struct.new('Message', :user, :channel, :text)

  def with_text(words)
    Message.new(uid, cid, words)
  end

  subject {
    SlackPrizes::Server.new(
      redis: redis,
      registry: registry
    )
  }

  before :each do
    redis.flushdb
  end

  describe 'Lovebirds' do
    it 'should record the length of a streak' do
      messages = [
        Message.new(uid_a, cid_a, 'blah'),
        Message.new(uid_b, cid_a, 'blah'),
        Message.new(uid_a, cid_a, 'blah'),
        Message.new(uid_b, cid_a, 'blah'),
      ]

      messages.each { |m| subject.process(m) }

      expect(redis.zscore(:lovebirds, "#{uid_b} #{uid_a}")).to eq(3)
    end

    it 'should interrupt a streak when someone else speaks in the same channel' do
      messages = [
        Message.new(uid_a, cid_a, 'blah'),
        Message.new(uid_b, cid_a, 'blah'),

        Message.new(uid_c, cid_a, 'blah'),

        Message.new(uid_a, cid_a, 'blah'),
        Message.new(uid_b, cid_a, 'blah'),
        Message.new(uid_a, cid_a, 'blah'),
        Message.new(uid_b, cid_a, 'blah'),
      ]

      messages.each { |m| subject.process(m) }

      expect(redis.zscore(:lovebirds, "#{uid_b} #{uid_a}")).to eq(3)
    end

    it 'should track the highest streak' do
      messages = [
        Message.new(uid_a, cid_a, 'blah'),
        Message.new(uid_b, cid_a, 'blah'),
        Message.new(uid_a, cid_a, 'blah'),
        Message.new(uid_b, cid_a, 'blah'),
        Message.new(uid_a, cid_a, 'blah'),
        Message.new(uid_b, cid_a, 'blah'),

        Message.new(uid_c, cid_a, 'blah'),

        Message.new(uid_a, cid_a, 'blah'),
        Message.new(uid_b, cid_a, 'blah'),
        Message.new(uid_a, cid_a, 'blah'),
        Message.new(uid_b, cid_a, 'blah'),
      ]

      messages.each { |m| subject.process(m) }

      expect(redis.zscore(:lovebirds, "#{uid_b} #{uid_a}")).to eq(5)
    end

    it 'should not interrupt a streak when something is said in a different channel' do
      messages = [
        Message.new(uid_a, cid_a, 'blah'),
        Message.new(uid_b, cid_a, 'blah'),
        Message.new(uid_a, cid_b, 'blah'),
        Message.new(uid_b, cid_b, 'blah'),
        Message.new(uid_a, cid_a, 'blah'),
        Message.new(uid_b, cid_a, 'blah'),
      ]

      messages.each { |m| subject.process(m) }

      expect(redis.zscore(:lovebirds, "#{uid_b} #{uid_a}")).to eq(3)
    end

    it 'should not interrupt a streak when a use speaks twice, but also not count towards length' do
      messages = [
        Message.new(uid_a, cid_a, 'blah'),
        Message.new(uid_b, cid_a, 'blah'),
        Message.new(uid_b, cid_a, 'blah'),
        Message.new(uid_a, cid_a, 'blah'),
        Message.new(uid_b, cid_a, 'blah'),
      ]

      messages.each { |m| subject.process(m) }

      expect(redis.zscore(:lovebirds, "#{uid_b} #{uid_a}")).to eq(3)
    end
  end
end
