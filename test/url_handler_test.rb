require 'epitools'
require 'logger'
require 'pry'

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
#test "http://www.youtube.com/watch?v=EDagAmVdbO8"
#test "https://github.com/rapportive-oss/git-bits"
#test "https://twitter.com/#!/cxdig/status/180789837501169665"
#test "http://snltranscripts.jt.org/01/01jbestlist.phtml"
#test "http://i.imgur.com/3JCsv.jpg"
#test "http://files.redux.com/images/9185b525dbd774fe49587d2399cc8809/raw"
#test "http://wuub.net/sublimerepl/debian1.png"
#test "https://twitter.com/#!/StephenMalkmus1"
#test "http://www.velvetglove.org/misc/macros/superslam.jpg"
#test "https://docs.redhat.com/docs/en-US/Red_Hat_Enterprise_Linux/6/html/Installation_Guide/ch-upgrade-x86.html"
#test "http://www.youtube.com/watch?v=nafScTaNa3k"
#test "https://github.com/rapid7/metasploit-framework/blob/master/lib/metasm/metasm/exe_format/elf.rb"
#test "https://twitter.com/TNG_S8/status/201408246785908736"
#test "https://www.youtube.com/watch?v=TR8TjCncvIw"
#test "https://twitter.com/conradirwin/status/216308529101930496"
#test "http://www.wired.com/business/2012/06/khan-academy"
#test "https://twitter.com/worrydream/status/217668956738158594"
#test "http://google.com/ http://twitter.com/ http://slashdot.org/"
#test "Asher: http://www.youtube.com/watch?v=yMazI2ROJXM"
#test "http://unicode.org/charts/PDF/U2400.pdf"
#test "http://erlangonxen.org/"
#test "https://twitter.com/oh_rodr/status/258661589232803840"
#test "https://twitter.com/Giancarlo818"
# test "http://en.wikipedia.org/wiki/Chickens"
test "http://en.wikipedia.org/wiki/Agenda_21"
# test "http://en.wikipedia.org/wiki/Israel"
