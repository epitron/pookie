require 'epitools'
require 'cinch'
require 'mechanize'
require 'cgi'
require 'logger'
require 'json'

#############################################################################
# Monkeypatches
#############################################################################

class String

  UNESCAPE_TABLE = {
    'nbsp'  => ' ',
    'ndash' => '-',
    'mdash' => '-',
    'amp'   => '&',
    'raquo' => '>>',
    'laquo' => '<<',
    'quot'  => '"',
    'micro' => 'u',
    'copy'  => '(c)',
    'trade' => '(tm)',
    'reg'   => '(R)',
    '#174'  => '(R)',
    '#8220' => '"',
    '#8221' => '"',
    '#8212' => '--',
    '#39'   => "'",
    '#8217' => "'",
  }

  def translate_html_entities
    # first pass -- let CGI have a crack at it...
    raw_title = CGI::unescapeHTML(self)

    # second pass -- fix things that won't display as ASCII...
    raw_title.gsub(/(&([\w\d#]+?);)/) do
      symbol = $2

      # remove the 0-paddng from unicode integers
      if symbol =~ /#(.+)/
        symbol = "##{$1.to_i.to_s}"
      end

      # output the symbol's irc-translated character, or a * if it's unknown
      UNESCAPE_TABLE[symbol] || '*'
    end
  end

  def to_params
    CGI.parse(self).map_values do |v|
      # CGI.parse wraps every value in an array. Unwrap them!
      if v.is_a?(Array) and v.size == 1
        v.first
      else
        v
      end
    end
  end
end

class Integer

  def to_hms
    seconds = self

    days, seconds    = seconds.divmod(86400)
    hours, seconds   = seconds.divmod(3600)
    minutes, seconds = seconds.divmod(60)

    result = "%0.2d:%0.2d" % [minutes,seconds]
    result = ("%0.2d:" % hours) + result   if hours > 0 or days > 0
    result = ("%0.2d:" % days) + result    if days > 0

    result
  end

  def commatize
    to_s.gsub(/(\d)(?=\d{3}+(?:\.|$))(\d{3}\..*)?/,'\1,\2')
  end

end

class Nokogiri::XML::Element
  def clean_text
    inner_text.strip.gsub(/\s*\n+\s*/, " ").translate_html_entities if inner_text
  end
end

class NilClass
  #
  # A simple way to make it so missing fields nils don't cause the app the explode.
  #
  def [](*args)
    nil
  end
end

class YouTubeVideo < Struct.new(
                :title,
                :thumbnails,
                :link,
                :description,
                :length,
                :user,
                :published,
                :updated,
                :rating,
                :raters,
                :keywords,
                :favorites,
                :views
              )

  def initialize(rec)

    media = rec["media$group"]

    self.title        = media["media$title"]["$t"]
    self.thumbnails   = media["media$thumbnail"].map{|r| r["url"]}
    self.link         = media["media$player"].first["url"].gsub('&feature=youtube_gdata_player','')
    self.description  = media["media$description"]["$t"]
    self.length       = media["yt$duration"]["seconds"].to_i
    self.user         = rec["author"].first["name"]["$t"]
    self.published    = DateTime.parse rec["published"]["$t"]
    self.updated      = DateTime.parse rec["updated"]["$t"]
    self.rating       = rec["gd$rating"]["average"]
    self.raters       = rec["gd$rating"]["numRaters"]
    self.keywords     = rec["media$group"]["media$keywords"]["$t"]
    self.favorites    = rec["yt$statistics"]["favoriteCount"].to_i
    self.views        = rec["yt$statistics"]["viewCount"].to_i
  end

end

module URI
  def params
    query.to_params
  end
end


#############################################################################
# Generic link info

#class Mechanize::Download
class Mechanize::File
  def size
    header["content-length"].to_i
  end

  def mimetype
    header["content-type"]
  end

  def link_info
    "type: \2#{mimetype}\2#{size <= 0 ? "" : ", size: \2#{size.commatize} bytes\2"}"
  end
end


#############################################################################
# Image info

class ImageParser < Mechanize::Download

  def peek(amount=4096)
    unless @result
      @result = body_io.read(amount)
      body_io.close
    end

    @result
  end

  def link_info
    tmp = Path.tempfile
    #tmp << peek
    tmp << body

    # avatar_6786.png PNG 80x80 80x80+0+0 8-bit DirectClass 15.5KB 0.000u 0:00.000
    # 2BXGik3.gif[49] GIF 450x219 450x330+0+69 8-bit sRGB 128c 2.012MB 0.000u 0:00.009
    lines  = `identify #{tmp}`.lines.to_a
    filename, type, dimensions, *extra = lines.last.split
    
    frameinfo = ""
    if lines.size > 1
      frameinfo = ", #{lines.size} frames"
    end


    if dimensions and type
      "image: \2#{dimensions} #{type}\2 (#{tmp.size.commatize} bytes#{frameinfo})"
    else
      "image: \2#{mimetype}\2 (#{size.commatize} bytes#{frameinfo})"
    end
  end

end


#############################################################################
# HTML link info

class HTMLParser < Mechanize::Page

  TITLE_RE = /<\s*?title\s*?>(.+?)<\s*?\/title\s*?>/im

  def get_title
    # Generic parser
    titles = search("title")
    if titles.any?
      title = titles.first.clean_text
      title = title[0..255] if title.length > 255
      title
    else
      nil
    end
  end

  def link_info
    # p uri.to_s

    # require 'pry'; binding.pry
    case uri.to_s

    when %r{^https?://[^\.]+\.wikipedia\.org/wiki/File:(.+)}
      info = at("#mw-content-text .fullMedia .fileInfo").clean_text

      if info =~ /\((.+)\)/
        info = $1
      end

      "wikimedia: #{info}"

    when %r{^https?://[^\.]+\.wikipedia\.org/wiki/(.+)}
      max_size   = 320
      min_size   = 60
      title      = at("#firstHeading").clean_text
      sentences  = []
      content = search("#bodyContent #mw-content-text")
      content.search("table").remove

      paragraphs = content.search("p")

      # remove extra crap
      paragraphs.search("p span[id='coordinates']").remove

      # add bolds
      paragraphs.search("b").each { |e| e.content = "\2#{e.content}\2" }

      # convert to text
      paragraphs = paragraphs.map(&:clean_text).reject(&:blank?)

      # split into an array of sentences
      for paragraph in paragraphs
        break if sentences.size > 20
        sentences += paragraph.split(/(?<=\.)(?:\[\d+\])* (?=[A-Z0-9])/)
      end

      summary = sentences.first

      # append sentences to the summary (up to a maximum, unless it's too short)
      sentences[1..-1].each do |sentence|
        test = "#{summary} #{sentence}"
        break if test.size > max_size and summary.size > min_size
        summary = test
      end

      # crop it if it's longer than the maximum size
      if summary.size > max_size
        summary = summary[0..max_size-3] + "..."
      end

      # "wikipedia: \2#{title}\2 - #{summary}"
      "wikipedia: #{summary}"

    when %r{^(https?://twitter\.com/)(?:#!/)?(.+/status(?:es)?/\d+)}
      # Twitter parser
      newurl  = "#{$1}#{$2}"
      page    = mech.get(newurl)

      # tweet   = page.at(".tweet-text").clean_text
      # inner_text.strip.gsub(/\s*\n+\s*/, " ").translate_html_entities if inner_text
      tweet   = page.at(".permalink-tweet .tweet-text").inner_text.strip.gsub(/\n+/, " / ").translate_html_entities
      tweeter = page.at(".permalink-tweet .username").text

      "tweet: <\2#{tweeter}\2> #{tweet}"

    when %r{^(https?://twitter\.com/)(?:#!/)?([^/]+)/?$}
      newurl    = "#{$1}#{$2}"
      page      = mech.get(newurl)

      username  = $2
      fullname  = page.at(".user-actions")["data-name"]

      tweets    = page.at("ul.stats li a[data-element-term='tweet_stats'] strong").clean_text
      followers = page.at("ul.stats li a[data-element-term='follower_stats'] strong").clean_text
      following = page.at("ul.stats li a[data-element-term='following_stats'] strong").clean_text

      "tweeter: \2@#{username}\2 (\2#{fullname}\2) | tweets: \2#{tweets}\2, following: \2#{following}\2, followers: \2#{followers}\2"


    when %r{^https?://(?:www\.)?github\.com/(?!blog)([^/]+?)/([^/]+?)/?$}
      watchers, forks = search("a.social-count").map(&:clean_text)

      desc     = at(".repository-description")
      #desc.at("span").remove
      desc     = desc.clean_text

      "github: \2#{$1}/#{$2}\2 - #{desc} (watchers: \2#{watchers}\2, forks: \2#{forks}\2)"


    when %r{^https?://(www\.)?soundcloud.com/}
      page = mech.get "http://soundcloud.com/oembed?url=#{CGI.escape uri.to_s}&format=json"
      json = page.body.from_json

      "soundcloud: \2#{json["title"]}\2"


    when %r{^https?://(www\.)?rottentomatoes\.com/m/.+}
      title          = at(".movie_title").clean_text
      genres         = search("span[itemprop='genre']").map(&:clean_text).join(", ")
      released       = at("span[itemprop='datePublished']")["content"]

      critics        = at("#all-critics-meter").clean_text
      critic_count   = at("span[itemprop='reviewCount']").clean_text.to_i.commatize rescue nil

      audience       = at(".meter.popcorn").clean_text rescue nil
      audience_count = at("a.fan_side p.critic_stats").clean_text.split.last

      result = "movie: \2#{title}\2"

      if critic_count and audience
        result += " - ratings: \2#{critics}%\2 (\2#{critic_count}\2 critics) / \2#{audience}%\2 (\2#{audience_count}\2 viewers),"
      end

      result += " released: \2#{released}\2, genres: #{genres}"

      result
      
    when %r{^https?://(www\.)?youtube\.com/watch\?}
      #views = at("span.watch-view-count").clean_text
      #date  = at("#eow-date").clean_text
      #time  = at("span.video-time").clean_text
      #title = at("#eow-title").clean_text

      video_id = uri.params["v"]
      page     = mech.get("http://gdata.youtube.com/feeds/api/videos/#{video_id}?v=1&alt=json")
      json     = page.body.from_json

      video    = YouTubeVideo.new(json["entry"])

      views    = video.views.commatize
      date     = video.published.strftime("%Y-%m-%d")
      time     = video.length.to_hms
      title    = video.title
      rating   = video.rating ? "%0.1f" % video.rating : "?"

      "video: \2#{title}\2 (length: \2#{time}\2, views: \2#{views}\2, rating: \2#{rating}\2, posted: \2#{date}\2)"
      #"< #{title} (length: #{time}, views: #{views}, posted: #{date}) >"


    when %r{^https?://(?:www\.)?blockchain\.info/tx/(.+)}
      id = $1
      page = mech.get("https://blockchain.info/rawtx/#{id}")
      data = JSON.parse page.body
      input_count = data["inputs"].size
      out_count = data["out"].size
      time = Time.at(data["time"])
      datestr = time.strftime("%Y-%m-%d")
      timestr = time.strftime("%H:%M")
      ip = data["relayed_by"]
      total_out = data["out"].inject(0) { |total,r| r["value"] + total }
      total_out = total_out.to_f / (10**8)

      "bitcoin transaction: \2#{total_out}\2 bitcoins (\2#{input_count}\2 inputs, \2#{out_count}\2 outputs, from \2#{ip}\2, at \2#{timestr}\2 on \2#{datestr}\2)"

    when %r{^https?://(?:www\.)?kickstarter\.com/projects/.+}
      title     = at("#title").clean_text
      subtitle  = at("#subtitle").clean_text

      stats     = at("#stats")
      remaining = stats.at("#project_duration_data")["data-hours-remaining"]
      backers   = stats.at("#backers_count")["data-backers-count"].to_i.commatize
      goal      = stats.at("#pledged")["data-goal"].to_i.commatize
      pledged   = stats.at("#pledged")["data-pledged"].to_i.commatize

      "kickstarter: \2#{title}\2 #{subtitle} (\2#{backers}\2 backers pledged \2$#{pledged}\2 of \2$#{goal}\2 goal; \2#{remaining}\2 hours remaining)"

    else
      if title = get_title
        "title: \2#{title}\2"
        #"< #{title} >"
      else
        nil
      end
    end
  end

  #--------------------------------------------------------------------------

  def get_title_from_html(pagedata)
    return unless TITLE_RE.match(pagedata)
    title = $1.strip.gsub(/\s*\n+\s*/, " ")
    title = unescape_title title
    title = title[0..255] if title.length > 255
    "title: \2#{title}\2"
  end

end


class TitleGrabber

  URL_MATCHER_RE = %r{(?:(?:f|ht)tps?://.*?)(?:\s|$)}i

  def initialize(debug: false)
    @debug = debug
  end

  def extract_urls(message)
    message.scan(URL_MATCHER_RE).map do |url|
      url.gsub(/[,\)]$/, '')
    end
  end

  def grab(url)
    page = agent.get(url)

    if page.respond_to? :link_info and title = page.link_info
      title
    else
      nil
    end
  rescue Mechanize::ResponseCodeError, SocketError => e
    nil
  end

  def agent
    @agent ||= Mechanize.new do |a|
      a.pluggable_parser["image"] = ImageParser
      a.pluggable_parser.html     = HTMLParser

      #a.user_agent_alias   = "Windows IE 7"
      a.user_agent          = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.4 (KHTML, like Gecko) Chrome/22.0.1229.94 Safari/537.4"
      a.max_history         = 0
      a.verify_mode         = OpenSSL::SSL::VERIFY_NONE
      a.redirect_ok         = true
      a.redirection_limit   = 5
      a.follow_meta_refresh = :anywhere

      if @debug
        a.log = Logger.new $stdout # FIXME: Assign this to the Cinch logger
      end
    end
  end

end


#############################################################################
# The Plugin
#############################################################################

module Cinch::Plugins

  class URLTitles
    include Cinch::Plugin

    # All events: http://rubydoc.info/gems/cinch/file/docs/events.md
    listen_to :message, :action

    IGNORE_NICKS = [
      /^CIA-\d+$/,
      /^travis-ci/,
      /^buttslave/,
      /^pry/,
      /^Xtopherus/,
      /^feepbot/,
      /^galileo/,
      /^eval-in/
    ]

    ### Handle All Lines of Chat ############################

    def titlegrabber
      @titlegrabber ||= TitleGrabber.new
    end

    def listen(m)
      return if IGNORE_NICKS.any? { |pattern| m.user.nick =~ pattern }

      debug "message: #{m.message.inspect}"
      url_list = titlegrabber.extract_urls(m.message)

      url_list.each do |url|
        debug "Getting info for #{url}..."

        if title = titlegrabber.grab(url) 
          debug title
          m.reply title
        else
          debug "Link info not found!"
        end
      end

    end

    #########################################################

    HTTP_STATUS_CODES = {
      000 => "Incomplete/Undefined error",
      201 => "Created",
      202 => "Accepted",
      203 => "Partial Information",
      204 => "Page does not contain any information",
      204 => "No response",
      206 => "Only partial content delivered",
      300 => "Page redirected",
      301 => "Permanent URL relocation",
      302 => "Temporary URL relocation",
      303 => "Temporary relocation method and URL",
      304 => "Document not modified",
      400 => "Bad request (syntax)",
      401 => "Unauthorized access (requires authentication)",
      402 => "Access forbidden (payment required)",
      403 => "Forbidden",
      404 => "URL not found",
      405 => "Method not Allowed (Most likely the result of a corrupt CGI script)",
      408 => "Request time-out",
      500 => "Internet server error",
      501 => "Functionality not implemented",
      502 => "Bad gateway",
      503 => "Service unavailable",
    }
    
  end

end