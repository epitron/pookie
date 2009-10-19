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
  
  def get_title_for_url(url, depth=10, max_bytes=30000)
    
    easy = Curl::Easy.new(url) do |c|
      # Gotta put yourself out there...
      c.headers["User-Agent"] = "Curl/Ruby"

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
    
    code = easy.response_code
    unless code == 200 or code == 403
      return "[Link Info] Error: #{code} #{HTTP_STATUS_CODES[code]}"
    end
    
    ### HTML page
    if easy.content_type =~ /^text\//

      data = ""
      easy.on_body{|chunk| data << chunk; data.size < max_bytes ? chunk.size : 0 }
      begin
        logger.debug "[get_title_for_url] GET #{url}"
        easy.url = easy.last_effective_url
        easy.perform
      rescue Exception => e
        logger.debug "RESCUED #{e.inspect}"
      end
      #data = easy.body_str
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

  def get_title_for_url2(uri_str, depth=10)
    # This god-awful mess is what the ruby http library has reduced me to.
    # Python's HTTP lib is so much nicer. :~(
    
    if depth == 0
      raise "Error: Maximum redirects hit."
    end
    
    url = URI.parse(uri_str)
    return if url.scheme !~ /https?/

    title = nil
    
    logger.debug "[get_title_for_url] connecting to #{url.host}:#{url.port}"
    Net::HTTP.start(url.host, url.port) { |http|
      url.path = '/' if url.path == ''

      http.request_get(url.path, "User-Agent" => "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)") { |response|
        
        case response
          when Net::HTTPRedirection, Net::HTTPMovedPermanently then
            # call self recursively if this is a redirect
            redirect_to = response['location']  || './'
            logger.debug "[get_title_for_url] redirect location: #{redirect_to.inspect}"
            url = URI.join url.to_s, redirect_to
            logger.debug "[get_title_for_url] whee, redirecting to #{url.to_s}!"
            return get_title_for_url(url.to_s, depth-1)
          when Net::HTTPSuccess then
            if response['content-type'] =~ /^text\//
              # since the content is 'text/*' and is small enough to
              # be a webpage, retrieve the title from the page
              logger.debug "[get_title_for_url] scraping title from #{url.request_uri}"
              data = read_data_from_response(response, 30000)
              return get_title_from_html(data)
            else
              # content doesn't have title, just display info.
              size = response['content-length'].gsub(/(\d)(?=\d{3}+(?:\.|$))(\d{3}\..*)?/,'\1,\2')
              return "[Link Info] type: #{response['content-type']}#{size ? ", size: #{size} bytes" : ""}"
            end
          when Net::HTTPClientError then
            return "[Link Info] Error getting link (#{response.code} - #{response.message})"
          when Net::HTTPServerError then
            return "[Link Info] Error getting link (#{response.code} - #{response.message})"
          else
            return nil
        end # end of "case response"
          
      } # end of request block
    } # end of http start block
    return title
  rescue SocketError => e
    return "[Link Info] Error connecting to site (#{e.message})"
  end


  def read_data_from_response(response, amount)
    
    amount_read = 0
    chunks = []
    
    response.read_body do |chunk|   # read body now
      
      amount_read += chunk.length
      
      if amount_read > amount
        amount_of_overflow = amount_read - amount
        chunk = chunk[0...-amount_of_overflow]
      end
      
      chunks << chunk

      break if amount_read >= amount
      
    end
    
    chunks.join('')
    
  end


  #exposes :what
  
  #def what(*args)
  #  p args
  #  reply "what"
  #end
end