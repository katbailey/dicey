require 'sinatra'
require 'json'

configure do
    require 'redis'
    uri = URI.parse(ENV["REDISCLOUD_URL"])
    $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

get '/' do
  $redis.set("foo", "bar")
  # => "OK"
  $redis.get("foo")
  # => "bar"
end
