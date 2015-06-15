require 'nokogiri'
require 'esa'
require "minitest/autorun"
require 'pry'

class Fetcher

  def initialize
    @client = Esa::Client.new(access_token: ENV["ESA_ACCESS_TOKEN"], current_team: ENV["ESA_TEAM"])
    date = Time.parse(ARGV[0])
    @response = @client.posts(q: "user:asonas category:日報/#{date.strftime("%Y/%m")}")
  end

  def posts
    @response.body["posts"]
  end

end
