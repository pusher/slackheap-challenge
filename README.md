# slackheap-challenge

## Dependencies

- redis

## BIG WARNINGS

The tests will run `flushdb` on redis db 14. You have been warned.

## Invocation

```
export SLACK_TOKEN=...
export REDIS_URL=...
bundle exec ruby app.rb
```

## Awesomenesses

Collect fun stats! Be notified in-channel when the leader for a category changes

## Shortcomings

The code is bad, the commit history worse, and the (limited) tests got broken as the deadline approached.

