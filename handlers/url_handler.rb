# Use this class to debug stuff as you 
# go along - e.g. dump events etc.
# options = {:ident=>"i=user", :host=>"unaffiliated/user", :nick=>"User", :message=>"this is a message", :target=>"#pookie-testing"}

#require 'curb'
require 'epitools'
require 'mechanize'
require 'cgi'
require 'logger'

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

end

class Nokogiri::XML::Element

  def clean_text
    if inner_text
      inner_text.strip.gsub(/\s*\n+\s*/, " ").translate_html_entities
    else
      nil
    end
  end

end

#############################################################################
# Generic link info
class Mechanize::Download
  def size
    header["content-length"].to_i
  end

  def link_info
    content_length = header["content-length"].to_i
    "type: \2#{content_type}\2#{content_length <= 0 ? "" : ", size: \2#{content_length.commatize} bytes\2"}"
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
    tmp << peek(500)

    # avatar_6786.png PNG 80x80 80x80+0+0 8-bit DirectClass 15.5KB 0.000u 0:00.000
    filename, type, dimensions, *extra = `identify #{tmp}`.split

    "info: \2#{dimensions} #{type}\2 (#{size.commatize} bytes)"
  end

end

#############################################################################
# HTML link info
class HTMLParser < Mechanize::Page

  TITLE_RE = /<\s*?title\s*?>(.+?)<\s*?\/title\s*?>/im
  
  def title
    # Generic parser
    titles = search("title")
    if titles.any?
      title = titles.first.clean_text
      title = unescape_title title
      title = title[0..255] if title.length > 255
      #get_title_from_html(body)
    else
      nil
    end
  end
  
  def link_info
    case uri.to_s
    when %r{(https?://twitter.com/)(?:#!/)?(.+/status/\d+)}
      # Twitter parser
      page = mech.get("#{$1}#{$2}")
      tweet = page.at(".entry-content").clean_text
      tweeter = page.at("a.screen-name").clean_text
      "tweet: <\2@#{tweeter}\2> #{tweet}"

    when %r{https?://(www.)?youtube.com/watch\?}
      views = at("span.watch-view-count").clean_text
      date = at("#eow-date").clean_text
      likes = at("span.watch-likes-dislikes").clean_text
      time = at("span.video-time").clean_text
      title = at("#eow-title").clean_text
      "video: \2#{title}\2 (#{time}, posted: #{date}) / #{views} views (#{likes})"

    else
      "title: \2#{title}\2"
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

#############################################################################
# The Plugin
#############################################################################

class UrlHandler < Marvin::CommandHandler

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

  URL_MATCHER_RE = %r{((f|ht)tps?://.*?)(?:\s|$)}i

  IGNORE_NICKS = [
    /^CIA-\d+$/,
    /^travis-ci/,
    /^buttslave/,
  ]

  #--------------------------------------------------------------------------

  ### Handle All Lines of Chat ############################

  #on_event :incoming_message, :look_for_url
  #desc "Looks for urls and displays the titles."
  #def look_for_url
  def handle_incoming_message(args)
    return if IGNORE_NICKS.any?{|pattern| args[:nick] =~ pattern}

    p args

    if args[:message] =~ URL_MATCHER_RE
      urlstr = $1.gsub(/([\)}\],.;!?]|\.{2,3})$/, '')
      
      logger.info "Getting info for #{urlstr}..."
      
      #title = get_title_for_url urlstr
      page = agent.get(urlstr)
      #title = get_title urlstr
      
      if page.respond_to? :link_info
        title = page.link_info
        say title, args[:target]
        logger.info title
      else
        logger.info "Link info not found!"
      end        
      
    end

  rescue Mechanize::ResponseCodeError, SocketError => e

    say "Error: #{e.message}"

  end

  ### Private methods... ###############################
  
  #--------------------------------------------------------------------------

  def agent
    @agent ||= Mechanize.new do |a|
      a.pluggable_parser["image"] = ImageParser
      a.pluggable_parser.html     = HTMLParser

      a.user_agent_alias          = "Windows IE 7"
      a.max_history               = 0
      a.log                       = Logger.new $stdout # FIXME: Assign this to the Marvin logger
    end
  end

  #--------------------------------------------------------------------------

  
=begin
  def old_get_title(url, depth=10, max_bytes=400000)
    
    easy = Curl::Easy.new(url) do |c|
      # Gotta put yourself out there...
      c.headers["User-Agent"] = "Curl/Ruby"
      c.encoding = "gzip,deflate"

      c.verbose = true
     
      c.follow_location = true
      c.max_redirects = depth
      
      c.timeout = 25
      c.connect_timeout = 10
      c.enable_cookies = true
      c.cookiefile = "/tmp/curb.cookies"

      # Allow self-signed certs
      c.ssl_verify_peer = false
      c.ssl_verify_host = false
    end
    
    logger.debug "[get_title_for_url] HEAD #{url}"
    
    begin
      easy.http_head
    rescue Exception => e
      return "Title Error: #{e}"
    end
    
    okay_codes = [200, 403, 405]
    code       = easy.response_code
    unless okay_codes.include? code
      return "Title Error: #{code} - #{HTTP_STATUS_CODES[code]}"
    end
    
    ### HTML page
    if easy.content_type.nil? or easy.content_type =~ /^text\//

      data = ""
      easy.on_body do |chunk| 
        # check if we found a title (making sure to include a bit of the last chunk incase the <title> tag got cut in half)
        found_title = ((data[-7..-1]||"") + chunk) =~ /<title>/
        
        data << chunk
        
        if data.size < max_bytes and !found_title
          # keep reading...
          chunk.size 
        else
          # abort!
          0
        end
      end
      
      begin
        logger.debug "[get_title_for_url] GET #{url}"
        easy.url = easy.last_effective_url
        easy.perform
      rescue Exception => e
        logger.debug "RESCUED #{e.inspect}"
      end
      return get_title_from_html(data)
    
    ### Binary file
    else
      # content doesn't have title, just display info.
      size = easy.downloaded_content_length #request_size
      return "type: \2#{easy.content_type}\2#{size <= 0 ? "" : ", size: \2#{commatize(size)} bytes\2"}"
    end
    
  end
=end

end
