# Use this class to debug stuff as you 
# go along - e.g. dump events etc.
# options = {:ident=>"i=epi", :host=>"unaffiliated/epitron", :nick=>"Epilogue", :message=>"asdf", :target=>"#pookie-testing"}

#require 'net/http'
#require 'uri'
require 'curb'
require 'cgi'

class UrlHandler < Marvin::CommandHandler

  TITLE_RE = /<\s*?title\s*?>(.+?)<\s*?\/title\s*?>/im
  
  UNESCAPE_TABLE = {
      'nbsp' => ' ',
      'raquo' => '>>',
      'quot' => '"',
      'micro' => 'u',
      'copy' => '(c)',
      'trade' => '(tm)',
      'reg' => '(R)',
      '#174' => '(R)',
      '#8220' => '"',
      '#8221' => '"',
      '#8212' => '--',
      '#39' => '\'',
  }
  
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

  ### Handle All Lines of Chat ############################

  #on_event :incoming_message, :look_for_url
  #desc "Looks for urls and displays the titles."
  #def look_for_url
  def handle_incoming_message(args)
    if args[:message] =~ /((f|ht)tps?:\/\/.*?)(?:\s+|$)/
      urlstr = $1
      
      logger.info "Getting title for #{urlstr}..."
      
      title = get_title_for_url urlstr
      
      if title
        say title, args[:target]
        logger.info title
      else
        logger.info "Title not found!"
      end        
      
    end
  end


  ### Private methods... ###############################
  
  def commatize(thing)
    thing.to_i.to_s.gsub(/(\d)(?=\d{3}+(?:\.|$))(\d{3}\..*)?/,'\1,\2')
  end
  
  def get_title_for_url(url, depth=10, max_bytes=400000)
    
    easy = Curl::Easy.new(url) do |c|
      # Gotta put yourself out there...
      c.headers["User-Agent"] = "Curl/Ruby"
      c.encoding = "gzip,deflate"

      c.verbose = true
     
      c.follow_location = true
      c.max_redirects = depth
      

      c.enable_cookies = true
      c.cookiefile = "/tmp/curb.cookies"
    end
    
    logger.debug "[get_title_for_url] HEAD #{url}"
    
    begin
      easy.http_head
    rescue Exception => e
      return "[Link Info] Error: #{e}"
    end
    
    okay_codes = [200, 403, 405]
    code       = easy.response_code
    unless okay_codes.include? code
      return "[Link Info] Error: #{code} - #{HTTP_STATUS_CODES[code]}"
    end
    
    ### HTML page
    if easy.content_type =~ /^text\//

      data = ""
      easy.on_body do |chunk| 
        # check if we found a title (making sure to include a bit of the last chunk incase the <title> tag got cut in half)
        found_title = ((data[-7..-1]||"") + chunk) =~ /<title>/
        
        data << chunk
        
        if data.size < max_bytes and !found_title
          # keep going
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
      #data = easy.body_str
      p [:data_size, data.size]
      p [:title, data.grep(/<title>/i)]
      return get_title_from_html(data)
    
    ### Binary file
    else
      # content doesn't have title, just display info.
      size = easy.downloaded_content_length #request_size
      return "[Link Info] type: #{easy.content_type}#{size ? ", size: #{commatize(size)} bytes" : ""}"
    end
    
  end
  
  def get_title_from_html(pagedata)
    return unless TITLE_RE.match(pagedata)
    title = $1.strip.gsub(/\s*\n+\s*/, " ")
    title = unescape_title title
    title = title[0..255] if title.length > 255
    "[Link Info] title: #{title}"
  end

  def unescape_title(htmldata)
    # first pass -- let CGI try to attack it...
    htmldata = CGI::unescapeHTML htmldata
    
    # second pass -- destroy the remaining bits...
    htmldata.gsub(/(&(.+?);)/) {
        symbol = $2
        
        # remove the 0-paddng from unicode integers
        if symbol =~ /#(.+)/
            symbol = "##{$1.to_i.to_s}"
        end
        
        # output the symbol's irc-translated character, or a * if it's unknown
        UNESCAPE_TABLE[symbol] || '*'
    }
  end

end
