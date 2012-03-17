require 'epitools'
require 'pry'
require 'logger'
require 'epitools'

class Marvin
  class CommandHandler

	  def logger
	    @logger ||= Logger.new STDOUT
	  end
	  
	  def say(*args)
	    #puts "<pookie> #{args.inspect}"
	  end

  end
end

load "#{__DIR__}/../handlers/url_handler.rb"

def message(line)
  $u ||= UrlHandler.new 
  args = {
    :nick => "testuser",
    :target => "dunno",
    :message => line,
  }
  $u.handle_incoming_message(args)
end

def test(str)
  p message(str)
end

#test "http://fffffffffffffzzzzzzzfffffffffffafafarrejrj23.net/badurl"
#test "http://google.com/)"
test "http://www.youtube.com/watch?v=EDagAmVdbO8"
#test "https://twitter.com/#!/cxdig/status/180789837501169665"
#test "http://snltranscripts.jt.org/01/01jbestlist.phtml"
#test "http://i.imgur.com/3JCsv.jpg"
#test "http://files.redux.com/images/9185b525dbd774fe49587d2399cc8809/raw"
#test "http://wuub.net/sublimerepl/debian1.png"
