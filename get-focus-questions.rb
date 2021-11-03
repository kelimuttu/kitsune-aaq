#!/usr/bin/env ruby
require 'json'
require 'rubygems'
require 'typhoeus'
require 'awesome_print'
require 'json'
require 'time'
require 'date'
require 'mongo'
require 'csv'
require 'logger'
require 'pp'

# based on:# https://github.com/rtanglao/2016-rtgram/blob/master/backupPublicVancouverPhotosByDateTaken.rb

logger = Logger.new(STDERR)
logger.level = Logger::DEBUG
Mongo::Logger.logger.level = Logger::FATAL

def getKitsuneResponse(url, params, logger)
  try_count = 0
  begin
    result = Typhoeus::Request.get(url,
                                 :params => params )
    logger.debug result.ai
    x = JSON.parse(result.body)
  rescue JSON::ParserError => e
    try_count += 1
    if try_count < 4
      $stderr.printf("JSON::ParserError exception, retry:%d\n",\
                     try_count)
      sleep(10)
      retry
    else
      $stderr.printf("JSON::ParserError exception, retrying FAILED\n")
      x = nil
    end
  end
  return x
end

MONGO_HOST = ENV["MONGO_HOST"]
raise(StandardError,"Set Mongo hostname in ENV: 'MONGO_HOST'") if !MONGO_HOST
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

if ARGV.length < 3
  puts "usage: #{$0} yyyy mm dd" #start date (since api always goes from latest backwards to the start date)
  exit
end

questionsColl = db[:questions]
questionsColl.indexes.create_one({ "id" => -1 }, :unique => true)
MIN_DATE = Time.local(ARGV[0].to_i, ARGV[1].to_i, ARGV[2].to_i, 0, 0) # may want Time.utc if you don't want local time

url_params = {
  :format => "json",
  :product => "focus-firefox",
  :ordering => "+created",
}

url = "https://support.mozilla.org/api/2/question/"
end_program = false
question_number = 0

while !end_program
  sleep(1.0) # sleep 1 second between API calls
  questions  = getKitsuneResponse(url, url_params, logger)
  url = questions["next"]
  logger.debug "next url:" + url
  url_params = nil
  questions["results"].each do|question|
    updated = question["updated"]
    logger.debug "updated:" + updated
    if !updated.nil?
      updated = Time.parse(question["updated"])
      logger.debug "QUESTION updated:" + updated.to_i.to_s
      question["updated"] = updated
    end
    logger.debug "created:" + question["created"]
    created = Time.parse(question["created"])
    logger.debug "QUESTION created:" + created.to_i.to_s
    question["created"] = created
    if created < MIN_DATE
      end_program = true
      break
    end
    id = question["id"]
    logger.debug "QUESTION id:" + id.to_s
    question_number += 1
    logger.debug "QUESTION number:" + question_number.to_s
    result_array = questionsColl.find({ 'id' => id }).update_one(question, :upsert => true ).to_a
    nModified = 0
    result_array.each do |item|
      nModified = item["nModified"] if item.include?("nModified")
      break
    end
    if nModified == 0
      logger.debug "INSERTED^^"
    else
      logger.debug "UPDATED^^^^^^"
    end
  end
end
