# encoding: utf-8 
#############################################################################
#
# TODOs:
#
# * Wikipedia: excerpt sub-sections of an article
# * META refresh: if the target page is the current page, or the delay is
#                 very high, then ignore the refresh.
#
#############################################################################
#
# IRC Text Formatting reference:
#
#                Bold: "\002"
#               Color: "\003"
#              Hidden: "\010"
#           Underline: "\037"
# Original Attributes: "\017"
#       Reverse Color: "\026"
#                Beep: "\007"
#             Italics: "\035" (2.10.0+)
#
#############################################################################

require 'epitools'
require 'cinch'
require 'mechanize'
require 'cgi'
require 'logger'
require 'json'

#############################################################################
# Not used at the moment, but maybe some day!

HTTP_STATUS_CODES = {
  000 => "Incomplete/Undefined error",
  201 => "Created",
  202 => "Accepted",
  203 => "Non-Authoritative Information",
  204 => "No Content",
  205 => "Reset Content",
  206 => "Partial Content",
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


#############################################################################
# Monkeypatches
#############################################################################

class Object
  def try(methodname); send(methodname); end
end

class NilClass
  def try(methodname); nil; end
  def clean_text; nil; end
end

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

  TRANSLATE_TABLE = {
    "—" => "--",
    "–" => "--",
    "•" => "|",
    "“" => '"',
    "”" => '"',
    "’" => "'",
    "‘" => "'",
  }

  def translate_html_entities
    # first pass -- let CGI have a crack at it...
    raw_title = CGI::unescapeHTML(self)

    # second pass -- fix things that won't display as ASCII...
    raw_title.gsub!(/(&([\w\d#]+?);)/) do
      symbol = $2

      # remove the 0-paddng from unicode integers
      if symbol =~ /#(.+)/
        symbol = "##{$1.to_i.to_s}"
      end

      # output the symbol's irc-translated character, or a * if it's unknown
      UNESCAPE_TABLE[symbol] || '*'
    end

    TRANSLATE_TABLE.each do |char, replacement|
      raw_title.gsub!(char, replacement)
    end

    raw_title
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
    case mimetype
    when %r{^text/plain}
      snippet = body[0..150]
      snippet += "..." if body.size > 150

      snippet = snippet.gsub(/[\n\r]+/, ' / ')

      "text: #{snippet}#{" (size: \2#{size.commatize} bytes\2)" if size > 0}"
    else
      "type: \2#{mimetype}\2#{size <= 0 ? "" : ", size: \2#{size.commatize} bytes\2"}"
    end
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
    filename, type, dimensions, *extra = lines.first.split
    
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

  def meta(property)
    at("meta[property='#{property}']")["content"]
  end

  def details(hash)
    hash.map do |k,v|
      if not v.blank?
        "#{k}: \2#{v}\2"
      end
    end.compact.join(", ")
  end

  def link_info

    case uri.to_s

    ##############################################################
    # Imgur
    when %r{^https?://(?:www\.|i\.)?imgur\.com/(?:gallery/|album/)?(\w+)(?:\.\w{3})?}
      # title == "imgur: the simple image sharer"

      # http://api.imgur.com/2/image/zTo8nk6.json
      # http://api.imgur.com/2/album/TuS3O.json
      # http://imgur.com/gallery/NyiVojz/comment/best/hit.json
      id       = $1
      response = mech.get("http://imgur.com/gallery/#{id}/comment/best/hit.json")
      data     = response.body.from_json["data"]["image"]

      # "hash"=>"lKk0Z4q",
      # "account_id"=>"3606994",
      # "account_url"=>"shenanigansen",
      # "title"=>"I hope I haven't miscategorized.",
      # "score"=>5519,
      # "starting_score"=>1,
      # "virality"=>2633.2473910225,
      # "size"=>530967,
      # "views"=>793978,
      # "is_hot"=>true,
      # "is_album"=>false,
      # "album_cover"=>nil,
      # "album_cover_width"=>0,
      # "album_cover_height"=>0,
      # "mimetype"=>"image/png",
      # "ext"=>".png",
      # "width"=>800,
      # "height"=>2977,
      # "animated"=>false,
      # "ups"=>5311,
      # "downs"=>189,
      # "points"=>5122,
      # "reddit"=>"/r/comics/comments/2hzkhu/i_hope_i_havent_miscategorized/",
      # "bandwidth"=>"392.62 GB",
      # "timestamp"=>"2014-10-01 13:13:24",
      # "hot_datetime"=>"2014-10-01 15:25:32",
      # "create_datetime"=>"2014-10-01 13:13:24",
      # "section"=>"comics",

      if data
        title  = data["title"]
        ups    = data["ups"].to_i
        downs  = data["downs"].to_i
        rating = ((ups.to_f/(ups + downs)) * 100).round(0) rescue 0

        deets = {
          views: data["views"],
          posted: data["timestamp"].split.first,
          size: "#{data["width"]}x#{data["height"]}",
          rating: rating
        }

        "imgur: \2#{title}\2 (#{details(deets)})"
      else
        nil
      end

    ##############################################################
    ## Wikipedia file
    when %r{^https?://[^\.]+\.wikipedia\.org/wiki/File:(.+)}
      info = at("#mw-content-text .fullMedia .fileInfo").clean_text

      if info =~ /\((.+)\)/
        info = $1
      end

      "wikimedia: #{info}"

    ##############################################################
    ## Wikipedia mobile 
    when %r{^https?://([^\.]+)\.m\.wikipedia\.org/wiki/(.+)}
      # redirect to the regular wikipedia
      page = mech.get("https://#{$1}.wikipedia.org/wiki/#{$2}")
      page.link_info

    ## {Wiki,Scholar}pedia
    when %r{^https?://[^\.]+\.(wikipedia)\.org/wiki/(.+)}, %r{^https?://[^\.]+\.(scholarpedia)\.org/article/(.+)}
      site      = $1
      max_size  = 320
      min_size  = 60
      title     = at("#firstHeading").clean_text
      sentences = []
      content   = search("#bodyContent #mw-content-text")
      content.search("table, .cp-curator-box, #sp_authors").remove

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
      "#{site}: #{summary}"

    ##############################################################
    ## Twitter account
    when %r{^(https?://(?:www|mobile\.)?twitter\.com/)(?:#!/)?([^/]+)/?$}
      # newurl  = "https://#{$2}#{$3}"
      # newurl    = "#{$1}#{$2}"
      # page      = mech.get(newurl)

      username  = $2
      fullname  = at(".user-actions")["data-name"]
      # tagline = at(".ProfileHeaderCard-bio").clean_text
      tagline = at(".bio").clean_text

      # deets = {
      #   "tweets"    => at(".ProfileNav-item--tweets.is-active .ProfileNav-value").clean_text,
      #   "followers" => at(".ProfileNav-item--followers .ProfileNav-value").clean_text,
      #   "following" => at(".ProfileNav-item--following .ProfileNav-value").clean_text,
      # }
      deets = {
        "tweets"    => at(".ProfileNav-item--tweets.is-active .ProfileNav-value").clean_text,
        "followers" => at(".ProfileNav-item--followers .ProfileNav-value").clean_text,
        "following" => at(".ProfileNav-item--following .ProfileNav-value").clean_text,
      }

      "tweeter: \2#{fullname}\2 | #{tagline} (#{details(deets)}"

    ##############################################################
    ## Twitter tweet
    when %r{^(https?://(?:www|mobile\.)?)(twitter\.com/)(?:#!/)?(.+/status(?:es)?/\d+)}
      # Twitter parser
      newurl  = "https://#{$2}#{$3}"
      page    = mech.get(newurl)


      # tweet   = page.at(".tweet-text").clean_text
      # inner_text.strip.gsub(/\s*\n+\s*/, " ").translate_html_entities if inner_text

      ### Old method (non-mobile)
      # tweet_node = page.at(".permalink-tweet .tweet-text")
      # tweet_node.search("a.twitter-timeline-link").each { |a| a.replace a["href"] } # replace anchor tags with just their hrefs

      # tweet   = tweet_node.inner_text.strip.gsub(/\n+/, " / ").translate_html_entities
      # tweeter = page.at(".permalink-header .username").text

      tweet_node = page.at(".main-tweet .tweet-text")
      tweet_node.search("a:not(.twitter-hashtag)").each do |a|
        # replace anchor tags with just their hrefs
        if full_url = a["data-expanded-url"]
          a.replace full_url
        elsif picture_id = a["data-tco-id"]
          a.replace "http://pic.twitter.com/#{picture_id}"
        else
          if a["href"].startswith("http")
            a.replace a["href"]
          else
            a.replace(a.text)
          end
        end
      end

      tweet   = tweet_node.inner_text.strip.gsub(/\n+/, " / ").translate_html_entities
      tweeter = page.at(".main-tweet .username").clean_text

      "tweet: <\2#{tweeter}\2> #{tweet}"

    ##############################################################
    ## Github user or org
    when %r{^https?://(?:www\.)?github\.com/([^/]+?)/?$}
      user = $1
      stats = mech.get("https://api.github.com/users/#{user}").body.from_json

      if at(".org-header")
        # {
        #   "login": "google",
        #   "id": 1342004,
        #   "avatar_url": "https://avatars.githubusercontent.com/u/1342004?v=3",
        #   "gravatar_id": "",
        #   "url": "https://api.github.com/users/google",
        #   "html_url": "https://github.com/google",
        #   "followers_url": "https://api.github.com/users/google/followers",
        #   "following_url": "https://api.github.com/users/google/following{/other_user}",
        #   "gists_url": "https://api.github.com/users/google/gists{/gist_id}",
        #   "starred_url": "https://api.github.com/users/google/starred{/owner}{/repo}",
        #   "subscriptions_url": "https://api.github.com/users/google/subscriptions",
        #   "organizations_url": "https://api.github.com/users/google/orgs",
        #   "repos_url": "https://api.github.com/users/google/repos",
        #   "events_url": "https://api.github.com/users/google/events{/privacy}",
        #   "received_events_url": "https://api.github.com/users/google/received_events",
        #   "type": "Organization",
        #   "site_admin": false,
        #   "name": "Google",
        #   "company": null,
        #   "blog": "https://developers.google.com/",
        #   "location": null,
        #   "email": null,
        #   "hireable": null,
        #   "bio": null,
        #   "public_repos": 701,
        #   "public_gists": 0,
        #   "followers": 0,
        #   "following": 0,
        #   "created_at": "2012-01-18T01:30:18Z",
        #   "updated_at": "2016-01-26T18:37:55Z"
        # }
        if desc = at(".org-header .org-description")
          desc = desc.clean_text
        else
          desc = user
        end

        deets = {
          "repos" => stats["public_repos"],
          "members" => at(".org-stats").clean_text,
        }

        "github: \2#{desc}\2 (#{details(deets)})"
      else
        # {
        #   "login": "banister",
        #   "id": 17518,
        #   "avatar_url": "https://avatars.githubusercontent.com/u/17518?v=3",
        #   "gravatar_id": "",
        #   "url": "https://api.github.com/users/banister",
        #   "html_url": "https://github.com/banister",
        #   "followers_url": "https://api.github.com/users/banister/followers",
        #   "following_url": "https://api.github.com/users/banister/following{/other_user}",
        #   "gists_url": "https://api.github.com/users/banister/gists{/gist_id}",
        #   "starred_url": "https://api.github.com/users/banister/starred{/owner}{/repo}",
        #   "subscriptions_url": "https://api.github.com/users/banister/subscriptions",
        #   "organizations_url": "https://api.github.com/users/banister/orgs",
        #   "repos_url": "https://api.github.com/users/banister/repos",
        #   "events_url": "https://api.github.com/users/banister/events{/privacy}",
        #   "received_events_url": "https://api.github.com/users/banister/received_events",
        #   "type": "User",
        #   "site_admin": false,
        #   "name": "John Mair",
        #   "company": "General Assembly",
        #   "blog": "http://twitter.com/banisterfiend",
        #   "location": "The Hague, Netherlands",
        #   "email": "jrmair@gmail.com",
        #   "hireable": true,
        #   "bio": null,
        #   "public_repos": 63,
        #   "public_gists": 838,
        #   "followers": 221,
        #   "following": 37,
        #   "created_at": "2008-07-19T11:18:47Z",
        #   "updated_at": "2016-02-06T10:14:19Z"
        # }        
        if full_name = at(".vcard-fullname")
          full_name = full_name.clean_text
        else
          full_name = name
        end

        deets = {
          "location" => stats["location"],
          "company" => stats["company"],
          "repos" => stats["public_repos"],
          "followers" => stats["followers"],
          "joined" => stats["created_at"].split("T").first,
        }

        "github: \2#{full_name}\2 (#{details(deets)})"
      end


    when %r{^https?://(?:www\.)?github\.com/(?!blog)([^/]+?)/([^/]+?)/?$}
      username, repo = $1, $2
      watchers, stars, forks = search("a.social-count").map(&:clean_text)

      desc = at(".repository-meta-content")
      if muted = desc.at(".text-muted")
        muted.remove
      end
      desc = desc.clean_text

      if time = at(".commit-tease time")
        last_commit = DateTime.parse(time["datetime"]).strftime("%Y-%m-%d\2 at \2%H:%M %p") rescue nil
      end

      deets = {
        "stars"       => stars, 
        "forks"       => forks, 
        "last commit" => last_commit
      }

      desc = "<No description>" if desc.blank?

      "github: \2#{desc}\2 (#{details(deets)})"


    ##############################################################
    ## Instagram post
    when %r{^https?://(?:www\.)?instagram\.com/p/([^/]+?)/?$}

      # <meta property="og:title" content="Elon Musk on Instagram: “Falcon lands on droneship, but the lockout collet doesn&#39;t latch on one the four legs, causing it to tip over post landing. Root cause may…”" />
      title = meta("og:title")

      # <meta property="og:type" content="video" />
      deets = {type: meta("og:type").split(":").last}

      if body =~ /"PostPage".+?"date":(\d+\.\d+),/
        deets[:date] = Time.at($1.to_f).strftime("%Y-%m-%d")
      end

      if body =~ /"likes":{"count":(\d+)/
        deets[:likes] = $1.to_i.commatize
      end

      if title =~ /^(.+?) on Instagram: (.+)$/
        user = $1
        title = $2.gsub(/(^“|”$)/, '')
        "instagram: <\2#{user}\2> \2#{title}\2 (#{details(deets)})"
      else
        "instagram: \2#{title}\2 (#{details(deets)})"
      end


    ##############################################################
    ## Soundcloud track
    when %r{^https?://(www\.)?soundcloud.com/}
      # page = mech.get "http://soundcloud.com/oembed?url=#{CGI.escape uri.to_s}&format=json"
      # json = page.body.from_json

      # <meta itemprop="interactionCount" content="UserLikes:5124" />
      # <meta itemprop="interactionCount" content="UserDownloads:0" />
      # <meta itemprop="interactionCount" content="UserComments:275" />
      props = search("meta[itemprop='interactionCount']").map { |e| e["content"].split(":") }
      props = Hash[props]

      likes = props["UserLikes"]

      # <meta property="og:title" content="Floating Points &amp; Four Tet - Final Plastic People 2 1 2015" />
      title = at("meta[property='og:title']")["content"]

      # <meta itemprop="duration" content="PT05H54M48S" />, in this format: http://en.wikipedia.org/wiki/ISO_8601#Durations
      length = at("meta[itemprop='duration']")["content"].scan(/\d+/).flatten.join(":")

      # <meta itemprop="name" content="floating points" />
      artist = at("meta[itemprop='name']")["content"]

      "soundcloud: \2#{title}\2 (by \2#{artist}\2, length: \2#{length}\2, likes: \2#{likes}\2)"


    ##############################################################
    ## Urbandictionary definition
    when %r{^https?://(www\.)?urbandictionary\.com/define.php\?term=.+}
      elem = search("#content").first

      word    = elem.at(".word").clean_text
      meaning = elem.at(".meaning").clean_text
      example = elem.at(".example").clean_text

      "urbandictionary: \2#{word}\2: #{meaning} (eg: #{example})"[0..320]


    ##############################################################
    ## Twitch account
    when %r{^https?://(?:www\.)?twitch\.tv/([^/]+)$}
      user = $1
      # {"content"=>"317070", "property"=>"og:title"},
      # {"content"=>"Twitch plays Large Scale Deep neural net (shout objects to dream about)",
      #  "property"=>"og:description"},

      # user = page.at("meta[@property='og:title']")["content"]
      # desc = page.at("meta[@property='og:description']")["content"]

      # stream.channel.name
      # stream.channel.display_name
      # stream.channel.views
      # stream.channel.status
      # stream.viewers
      # stream.created_at

      json       = mech.get("http://api.twitch.tv/kraken/streams/#{user}?on_site=1").body.from_json

      viewers    = json["stream"]["viewers"]
      started_at = DateTime.parse json["stream"]["created_at"]
      title      = json["stream"]["channel"]["status"].tighten

      "twitch: \2#{title}\2 (viewers: \2#{viewers}\2, started: \2#{started_at.strftime("%l:%M\2%p, \2%b %e")}\2)"

    ##############################################################
    ## Rottentomatoes movie
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

    ##############################################################
    ## Youtube video
    when %r{^https?://(www\.)?youtube\.com/watch\?}
      # {"property"=>"og:title", "content"=>"Grass- Silent Partner"},
      # {"name"=>"title", "content"=>"Grass- Silent Partner"},
      title = at("meta[@property='og:title']")["content"]

      # {"itemprop"=>"datePublished", "content"=>"2013-10-05"},
      date = at("meta[@itemprop='datePublished']")["content"]

      # {"itemprop"=>"duration", "content"=>"PT5M4S"},
      duration = at("meta[@itemprop='duration']")["content"]
      duration = duration.scan(/\d+/).map { |n| "%0.2d" % n.to_i }.join(":")

      likes = at("#watch8-sentiment-actions .like-button-renderer-like-button-unclicked .yt-uix-button-content")
      dislikes = at("#watch8-sentiment-actions .like-button-renderer-dislike-button-unclicked .yt-uix-button-content")

      if likes and dislikes
        likes, dislikes = [likes, dislikes].map {|n| n.text.gsub(/\D/, '').to_i }
        rating = "%0.1f%" % ( (likes.to_f / (likes + dislikes)) * 100.0)
      else
        rating = "disabled"
      end

      views = at(".watch-view-count").clean_text

      "video: \2#{title}\2 (length: \2#{duration}\2, views: \2#{views}\2, rating: \2#{rating}\2, posted: \2#{date}\2)"

    ##############################################################
    ## Bitcoin transaction
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

    ##############################################################
    ## Kickstarter project
    when %r{^https?://(?:www\.)?kickstarter\.com/projects/.+}
      # <meta property="og:title" content="Ace of Space"/>
      # <meta property="og:description" content="Ace of Space is an oddball narrative 3D space shooter, set in the space future, with an exciting single player space story. For PC!"/>

      # title     = at("#project-header .title h2").clean_text
      # subtitle  = at("#project-header .creator").clean_text
      title = at("meta[property='og:title']")["content"]

      stats     = at("#stats")
      remaining = stats.at("#project_duration_data")["data-hours-remaining"].to_f.round(2)
      backers   = stats.at("#backers_count")["data-backers-count"].to_i.commatize
      goal      = stats.at("#pledged")["data-goal"].to_i.commatize
      pledged   = stats.at("#pledged")["data-pledged"].to_i.commatize

      # "kickstarter: \2#{title}\2 #{subtitle} (\2#{backers}\2 backers pledged \2$#{pledged}\2 of \2$#{goal}\2 goal; \2#{remaining}\2 hours remaining)"
      "kickstarter: \2#{title}\2 (\2#{backers}\2 backers pledged \2$#{pledged}\2 of \2$#{goal}\2 goal; \2#{remaining}\2 hours remaining)"


    ##############################################################
    ## SSssseeecrreettss      
    when %r{^https?://onetimesecret\.com/secret/}
      "title: \2Ssshhh.. it's a secret!\2"

    ##############################################################
    ## Eval.in codepaste
    when %r{^https?://(www\.)?eval\.in}
      nil

    ##############################################################
    ## Fallback: <title> tag
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
    if pagedata =~ /<\s*?title\s*?>(.+?)<\s*?\/title\s*?>/im
      title = $1.strip.gsub(/\s*\n+\s*/, " ")
      title = unescape_title title
      title = title[0..255] if title.length > 255
      "title: \2#{title}\2"
    end
  end

end

#############################################################################

class TitleGrabber

  URL_MATCHER_RE = %r{(?:(?:f|ht)tps?://.+?)(?:\s|$)}i

  def initialize(debug=false)
    @debug = debug
  end

  def extract_urls(message)
    message.scan(URL_MATCHER_RE).map do |url|
      url.gsub(/[,\)]$/, '')
    end
  end

  def grab(url)
    page = Timeout.timeout(30) { agent.get(url) }

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
      a.user_agent          = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.85 Safari/537.36"
      a.max_history         = 0
      a.verify_mode         = OpenSSL::SSL::VERIFY_NONE
      a.redirect_ok         = true
      a.redirection_limit   = 5
      a.follow_meta_refresh = :anywhere
      # a.open_timeout        = 60
      # a.read_timeout        = 180

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
    listen_to :message

    IGNORE_NICKS = [
      /^CIA-\d+$/,
      /^travis-ci/,
      /^buttslave/,
      /^pry/,
      /^Xtopherus/,
      /^feepbot/,
      /^galileo/,
      /^eval-in/,
      /^kanzure/,
      /^JosephStalin/
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

    rescue Timeout::Error
      debug "Timeout!"
    end

    #########################################################

  end

end
