require 'sinatra'
require 'json'
require 'redis-namespace'

configure do
    require 'redis'
    uri = URI.parse(ENV["REDISCLOUD_URL"])
    $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

r = Redis::Namespace.new(:ns, :redis => @r)
get '/' do
  @strategies = r.LRANGE("strategies", 0, -1)
  'Hello world!'
end
