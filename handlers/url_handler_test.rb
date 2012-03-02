require 'pry'
require 'logger'

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

load "url_handler.rb"

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
