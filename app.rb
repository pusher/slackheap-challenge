$:.push(File.expand_path('../lib', __FILE__))

require 'slack-prizes'

redis = Redis.new(db: 15)

SlackPrizes::SinatraApp.redis = redis

thin_server = Thin::Server.new(
  ENV['HOST'] || '127.0.0.1',
  ENV['PORT'] || '4545',
  SlackPrizes::SinatraApp,
  signals: false
)
Thread.new { thin_server.start }

SlackPrizes::Server.new(
  redis: redis,
  registry: SlackPrizes::UsefulRegistry.new(redis: redis)
).go
