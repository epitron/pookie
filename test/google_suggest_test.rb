require 'epitools'

class Marvin
  class CommandHandler

	  def logger
	    @logger ||= Logger.new STDOUT
	  end

	  def say(*args)
	    puts "<pookie> #{args.join ' '}"
	  end

    def self.exposes(thing)
    end

  end
end

load "#{__DIR__}/../handlers/google_suggest_handler.rb"

def message(line)
  $u ||= GoogleSuggestHandler.new
  args = {
    :nick => "testuser",
    :target => "dunno",
    :message => line,
  }
  $u.suggest(args)
end

def test(str)
  p message(str)
end

test "how do you"