require 'esa'
require 'nokogiri'
require 'time'

require 'pry'
require 'awesome_print'

module StarPlutinum

  class Ora
    attr_accessor :monthly

    def initialize
      fetcher = Fetcher.new
      @posts = fetcher.response.body["posts"]
      @monthly = []
    end

    def each
      Parser.new(@posts).each_calculate do |post|
        @monthly << post
        yield post
      end
    end

    def monthly_summing_work_time
      time = @monthly.map do |calc|
        calc.summing_work_time
      end.inject(:+)

      time / 3600
    end


    def worked_days
      @posts.length
    end
  end

  class Fetcher
    attr_accessor :response
    def initialize
      @client = Esa::Client.new(access_token: ENV["ESA_ACCESS_TOKEN"], current_team: ENV["ESA_TEAM"])
      date = Time.parse(ARGV[0])
      @response = @client.posts(q: "user:asonas category:日報/#{date.strftime("%Y/%m")}")
    end

  end

  class Parser
    def initialize(posts)
      @posts = posts
    end

    def each_calculate
      work_times = @posts.map do |post|
        document = Nokogiri::HTML post["body_html"]
        work_time_table = document.xpath("//h1").first.next_element

        temp = []
        document.xpath("//h1").first.next_element.xpath("//tbody/tr").each do |tr|
          next if tr.elements[0].text == "合計"
          temp << {
            title:      post["full_name"],
            place:      tr.elements[0].text,
            started_at: started_at(tr.elements[1].text),
            ended_at:   ended_at(tr.elements[1].text),
          }
        end
        temp
      end

      work_times.each do |work_time|
        yield Calcurator.new(work_time)
      end
    end

    private

    def started_at(unparsing_date)
      unparsing_date.split("-")[0]
    end

    def ended_at(unparsing_date)
      unparsing_date.split("-")[1]
    end
  end

  class Calcurator

    attr_accessor :summing_work_time

    def initialize(work_time)
      @work_time_sections = work_time
    end

    def title
      @work_time_sections.first[:title]
    end

    def started_at
      @work_time_sections.first[:started_at]
    end

    def ended_at
      @work_time_sections.last[:ended_at]
    end

    def calculate!
      secconds = @work_time_sections.map do |section|
        started_at = FisicalTime.new(section[:started_at]).relative_datetime
        ended_at = FisicalTime.new(section[:ended_at]).relative_datetime

        ended_at - started_at
      end.inject(:+)
      @summing_work_time = secconds

      return nil
    end

    def places
      @work_time_sections.map do |section|
        section[:place]
      end
    end

    class FisicalTime
      def initialize(time)
        @day = 1
        @undecision_time = time
        @time = if orver_day?
          next_day!
        else
          time
        end
      end

      def hour
        @undecision_time.split(":").first.to_i
      end

      def minutes
        @undecision_time.split(":").last.to_i
      end

      def orver_day?
        return true if hour > 24
        return true if minutes > 0
        false
      end

      def next_day!
        @day = 2
        return hour - 24
      end

      def relative_datetime
        Time.parse("1/#{@day} #{@time}:#{minutes}")
      end
    end
  end
end

oraora = StarPlutinum::Ora.new

oraora.each do |ora|
  puts "-" * 10
  puts ora.title
  puts "始業: #{ora.started_at}"
  puts "終業: #{ora.ended_at}"
  ora.calculate!
  puts "合計: #{(Time.parse("1/1") + ora.summing_work_time).strftime('%H時間%M分%S秒')}"
  puts "働いていた場所: #{ora.places.join(',')}"
end

puts "/" * 30
puts "働いていた日数: #{oraora.worked_days}"
puts "今月働いていた時間: #{oraora.monthly_summing_work_time}"
