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

p message("http://fffffffffffffzzzzzzzfffffffffffafafarrejrj23.net/badurl")
p message("http://google.com/")
p message("http://files.redux.com/images/9185b525dbd774fe49587d2399cc8809/raw")
