require 'sinatra'
require 'json'
require 'sinatra/cross_origin'

configure do
    require 'redis'
    enable :cross_origin
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
  keys = $redis.keys("*")
  keys.each do |k|
    $redis.del(k)
  end
  "deleted everything"
end

post '/strategies' do
  return_message = {}
    jdata = JSON.parse(params[:data],:symbolize_names => true)
    error(400, "Bad Request") unless jdata.has_key?(:name) && jdata.has_key?(:cid) && jdata.has_key?(:options)
    url_pattern = /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/
    jdata[:options].each do |u|
      if (!u[:type] || !u[:url] || !u[:thumbnail_url] || !url_pattern.match(u[:url]) || !url_pattern.match(u[:thumbnail_url]))
        error(400, "All options must have valid URLs")
      end
    end
    strategies = $redis.lrange("strategies", 0, -1)
    strategy_name = jdata[:name].strip()
    exists = false
    strategies.each do |s|
      exists = true if s == strategy_name
    end
    $redis.lpush("strategies", strategy_name) unless exists
    key_prefix = "strategies:#{strategy_name}"
    $redis.set("#{key_prefix}:cid", jdata[:cid])
    $redis.lpush("cids:#{jdata[:cid]}:strategies", strategy_name)
    $redis.set("#{key_prefix}:numoptions", jdata[:options].length)
    jdata[:options].each_index do |i|
      option_key_prefix = "#{key_prefix}:option:#{i}"
      $redis.set("#{option_key_prefix}:type", jdata[:options][i][:type])
      $redis.set("#{option_key_prefix}:url", jdata[:options][i][:url])
      $redis.set("#{option_key_prefix}:thumbnailurl", jdata[:options][i][:thumbnail_url])
    end
    return_message[:status] = "OK"
end

get '/strategies/:name' do
  strategy_name = params['name'].strip()
  key_prefix = "strategies:#{strategy_name}"
  strategy_cid = $redis.get("#{key_prefix}:cid")
  i = 0
  num_options = $redis.get("#{key_prefix}:numoptions").to_i
  strategy_options = []
  while i < num_options do
    option_key_prefix = "#{key_prefix}:option:#{i}"
    option = Hash.new()
    option[:type] = $redis.get("#{option_key_prefix}:type")
    option[:url] = $redis.get("#{option_key_prefix}:url")
    option[:thumbnail_url] = $redis.get("#{option_key_prefix}:thumbnailurl")
    strategy_options.push(option)
    i += 1
  end

  error(404, "Strategy info not found") if strategy_cid.nil? || strategy_options.nil?
  resp = Hash.new()
  resp[:name] = strategy_name
  resp[:cid] = strategy_cid
  resp[:options] = strategy_options
  resp.to_json
end

get '/decision' do
  error(400, "Bad Request") unless params[:cid] && params[:pid]
  my_strategies = []
  strategies = $redis.lrange("cids:#{params[:cid]}:strategies", 0, -1)
  halt 204 if strategies.nil?
  strategies.each do |s|
    my_strategies.push(s)
  end
  key_prefix = "strategies:#{my_strategies[0]}"
  num_options = $redis.get("#{key_prefix}:numoptions")
  halt 204 if num_options.nil?

  choice = rand(num_options.to_i)
  option_key_prefix = "#{key_prefix}:option:#{choice}"
  chosen_item = Hash.new()
  chosen_item[:type] = $redis.get("#{option_key_prefix}:type")
  chosen_item[:url] = $redis.get("#{option_key_prefix}:url")
  chosen_item[:thumbnail_url] = $redis.get("#{option_key_prefix}:thumbnailurl")

  resp = Hash.new()
  resp[:cid] = params[:cid]
  
  choices = []
  choices.push(chosen_item)
  resp[:outcome] = choices
  resp.to_json
end
