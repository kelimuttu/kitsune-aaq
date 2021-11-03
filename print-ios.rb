#!/usr/bin/env ruby
require 'json'
require 'rubygems'
require 'awesome_print'
require 'time'
require 'date'
require 'mongo'
require 'logger'
require 'csv'

logger = Logger.new(STDERR)
logger.level = Logger::DEBUG
Mongo::Logger.logger.level = Logger::FATAL
MONGO_HOST = ENV["MONGO_HOST"]
xfraise(StandardError,"Set Mongo hostname in ENV: 'MONGO_HOST'") if !MONGO_HOST
MONGO_PORT = ENV["MONGO_PORT"]
raise(StandardError,"Set Mongo port in ENV: 'MONGO_PORT'") if !MONGO_PORT
MONGO_USER = ENV["MONGO_USER"]
# raise(StandardError,"Set Mongo user in ENV: 'MONGO_USER'") if !MONGO_USER
MONGO_PASSWORD = ENV["MONGO_PASSWORD"]
# raise(StandardError,"Set Mongo user in ENV: 'MONGO_PASSWORD'") if !MONGO_PASSWORD
SUMO_QUESTIONS_DB = ENV["SUMO_QUESTIONS_DB"]
raise(StandardError,\
      "Set SUMO questions  database name in ENV: 'SUMO_QUESTIONS_DB'") \
if !SUMO_QUESTIONS_DB

host_with_port = sprintf("mongodb://%s:%d", MONGO_HOST, MONGO_PORT)

db = Mongo::Client.new(host_with_port, :database => SUMO_QUESTIONS_DB)
if MONGO_USER
  auth = db.authenticate(MONGO_USER, MONGO_PASSWORD)
  if !auth
    raise(StandardError, "Couldn't authenticate, exiting")
    exit
  end
end

if ARGV.length < 7
  puts "usage: #{$0} yyyy mm dd yyyy mm dd filename"
  exit
end

questionsColl = db[:questions]
MIN_DATE = Time.utc(ARGV[0].to_i, ARGV[1].to_i, ARGV[2].to_i, 0, 0) # may want Time.local
MAX_DATE = Time.utc(ARGV[3].to_i, ARGV[4].to_i, ARGV[5].to_i, 23, 59) # may want Time.local

FILENAME = ARGV[6]

headers = ['url','created', 'content', 'tags', 'locale', 'product']
CSV.open(FILENAME, 'w', write_headers: true, headers: headers) do |csv|
  questionsColl.find({:created =>
  {
    :$gte => MIN_DATE,
    :$lte => MAX_DATE},
    'product' => 'ios',
    'locale' => 'en-US' }
  ).sort(
  {"id"=> 1}
  ).projection(
  {
    "id" => 1,
    "content" => 1,
    "locale" => 1,
    "created" => 1,
    "tags" => 1,
    "product" => 1,
  }).each do |q|
    id = q["id"] 
    locale = q["locale"]
    content = q["content"]
    tags = q["tags"]
    logger.debug "QUESTION id:" + id.to_s
    url = "https://support.mozilla.org/" + locale + "/questions/" + id.to_s
    csv << [url, Time.at(q["created"]).utc, content, tags, locale, q["product"]]
  end
end
