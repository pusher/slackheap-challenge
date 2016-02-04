$:.push(File.expand_path('../lib', __FILE__))

require 'slack-prizes'

thin_server = Thin::Server.new(
  ENV['HOST'] || '127.0.0.1',
  ENV['PORT'] || '4545',
  SlackPrizes::SinatraApp,
  signals: false
)

redis = Redis.new(db: 15)

SlackPrizes::SinatraApp.redis = redis

SlackPrizes::Server.new(
  thin_server: thin_server,
  redis: redis,
  registry: SlackPrizes::UsefulRegistry.new(redis: redis)
).go
