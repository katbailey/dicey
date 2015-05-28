require 'sinatra'
require 'json'

configure do
    require 'redis'
    uri = URI.parse(ENV["REDISCLOUD_URL"])
    $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

get '/' do
  "O HAI!"
end

get '/strategies' do
  my_strategies = []
  strategies = $redis.lrange("strategies", 0, -1)
  strategies.each do |s|
    my_strategies.push(s)
  end
  my_strategies.to_json
end

delete '/strategies' do
  $redis.del("strategies")
  "deleted all strategies"
end

post '/strategies' do
  return_message = {}
    jdata = JSON.parse(params[:data],:symbolize_names => true)
    error(400, "Bad Request") unless jdata.has_key?(:name) && jdata.has_key?(:cid) && jdata.has_key?(:options)
    strategies = $redis.lrange("strategies", 0, -1)
    strategy_name = jdata[:name].strip()
    exists = false
    strategies.each do |s|
      exists = true if s == strategy_name
    end
    $redis.lpush("strategies", strategy_name) if !exists
    key_prefix = "strategies:#{strategy_name}"
    $redis.set("#{key_prefix}:cid", jdata[:cid])
    $redis.lpush("cids:#{jdata[:cid]}:strategies", strategy_name)
    $redis.set("#{key_prefix}:options", jdata[:options].join(','))
    return_message[:status] = "OK"
end

get '/strategies/:name' do
  strategy_name = params['name'].strip()
  key_prefix = "strategies:#{strategy_name}"
  strategy_cid = $redis.get("#{key_prefix}:cid")
  strategy_options = $redis.get("#{key_prefix}:options")
  error(404, "Strategy info not found") if strategy_cid.nil? || strategy_options.nil?
  resp = Hash.new()
  resp[:name] = strategy_name
  resp[:cid] = strategy_cid
  resp[:options] = strategy_options.split(',')
  resp.to_json
end

get '/decision' do
  error(400, "Bad Request") unless params[:cid] && params[:pid]
  my_strategies = []
  strategies = $redis.lrange("cids:#{params[:cid]}:strategies", 0, -1)
  strategies.each do |s|
    my_strategies.push(s)
  end
  items = $redis.get("strategies:#{my_strategies[0]}:options")
  error(404, "No such container") if items.nil?
  items_array = items.split(',')
  choice = rand(items_array.length)
  choices = []
  choices.push(items_array[choice].strip())
  choices.to_json
end
