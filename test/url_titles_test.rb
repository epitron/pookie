require 'logger'
require 'ostruct'
require 'epitools/colored'

require_relative "../plugins/url_titles"

def test(message)
  p message: message

  g    = TitleGrabber.new(debug: true)
  urls = g.extract_urls(message)

  p urls: urls

  urls.each do |url|
    result = g.grab(url)

    bold = false
    bolded = result.gsub("\2") do |m| 
      if bold
        bold = false
        "</11>"
      else
        bold = true
        "<11>"
      end
    end

    puts "<9>#{bolded}</9>".colorize
  end
end

# test "http://fffffffffffffzzzzzzzfffffffffffafafarrejrj23.net/badurl"
# test "http://google.com/)"
# test "http://www.youtube.com/watch?v=EDagAmVdbO8"
# test "https://github.com/rapportive-oss/git-bits"
# test "https://twitter.com/#!/cxdig/status/180789837501169665"
# test "http://snltranscripts.jt.org/01/01jbestlist.phtml"
# test "http://i.imgur.com/3JCsv.jpg"
# test "http://files.redux.com/images/9185b525dbd774fe49587d2399cc8809/raw"
# test "http://wuub.net/sublimerepl/debian1.png"
# test "https://twitter.com/#!/StephenMalkmus1"
# test "http://www.velvetglove.org/misc/macros/superslam.jpg"
# test "https://docs.redhat.com/docs/en-US/Red_Hat_Enterprise_Linux/6/html/Installation_Guide/ch-upgrade-x86.html"
# test "http://www.youtube.com/watch?v=nafScTaNa3k"
# test "https://github.com/rapid7/metasploit-framework/blob/master/lib/metasm/metasm/exe_format/elf.rb"
# test "https://twitter.com/TNG_S8/status/201408246785908736"
# test "https://www.youtube.com/watch?v=TR8TjCncvIw"
# test "https://twitter.com/conradirwin/status/216308529101930496"
# test "http://www.wired.com/business/2012/06/khan-academy"
# test "https://twitter.com/worrydream/status/217668956738158594"
# test "http://google.com/ http://twitter.com/ http://slashdot.org/"
# test "Asher: http://www.youtube.com/watch?v=yMazI2ROJXM"
# test "http://unicode.org/charts/PDF/U2400.pdf"
# test "http://erlangonxen.org/"
# test "https://twitter.com/oh_rodr/status/258661589232803840"
# test "https://twitter.com/Giancarlo818"
# test "http://en.wikipedia.org/wiki/Chickens"
# test "http://en.wikipedia.org/wiki/Agenda_21"
# test "http://en.wikipedia.org/wiki/Israel"
# test "https://twitter.com/stevelosh/status/340183472373129216"
# test "https://twitter.com/bcardarella/status/343762719880671232"
# test "http://www.rottentomatoes.com/m/this_is_the_end/"
# test "http://www.rottentomatoes.com/m/v_tumane_2012/"
# test "http://www.rottentomatoes.com/m/20_feet_from_stardom/"
# test "http://www.rottentomatoes.com/m/star_trek_into_darkness/"
# test "https://github.com/blog/1547-release-your-software"
# test "https://github.com/epitron/package_control_channel"
# test "https://soundcloud.com/strictly/sometime-in-the-future"
# test "http://i.imgur.com/2BXGik3.gif"
# test "http://i.imgur.com/8A1dnQJ.jpg"
# test "http://www.rottentomatoes.com/m/the_book_thief/"
# test "https://en.wikipedia.org/wiki/Stambovsky_v._Ackley"
# test "https://realworldocaml.org/"
# test "https://blockchain.info/tx/1c12443203a48f42cdf7b1acee5b4b1c1fedc144cb909a3bf5edbffafb0cd204"
# test "http://en.wikipedia.org/wiki/File:Orlovsky_and_Oculus_Rift.jpg"
# test "https://github.com/basecamp/bcx-api/"
# test "https://www.kickstarter.com/projects/mossmann/hackrf-an-open-source-sdr-platform"
# test "http://mag.newsweek.com/2014/03/14/bitcoin-satoshi-nakamoto.html?piano_t=1/"
# test "http://t.co/7Rk2k8iOIK"
# test "https://docs.google.com/presentation/d/1Sv8IHkBtBEXjSW7WktEYg4EbAUHtVyXIZBrAGD3WR5Y/"
# test "https://floobits.com/security,"
# test "http://http-keys.gnupg.net/"
# test "https://twitter.com/Helena_LB/status/458571238101635072"
# test "https://twitter.com/HackerNewsOnion"
# test "https://mobile.twitter.com/HackerNewsOnion"
# test "https://medium.com/matter/f4a5d98a4f51/"
# test "http://www.bloomberg.com/news/2014-05-21/brain-training-seen-as-dud-for-attention-deficit-children.html"
# test "https://twitter.com/LocoElPillo"
# test "http://www.theregister.co.uk/2014/05/28/truecrypt_hack/"
# test "http://arstechnica.com/security/2014/05/truecrypt-is-not-secure-official-sourceforge-page-abruptly-warns/"
# test "https://twitter.com/ProgrammingCom/status/471080343877853185"
# test "https://www.instapaper.com/text?u=http%3A%2F%2Fwww.businessweek.com%2Farticles%2F2014-06-11%2Fwith-the-machine-hp-may-have-invented-a-new-kind-of-computer"
# test "https://twitter.com/_dskuza/status/489869132406337536"
# test "http://www.urbandictionary.com/define.php?term=gwai%20lo"
# test "http://imgur.com/onnyQvZ"
# test "http://imgur.com/zTo8nk6"
# test "http://www.rottentomatoes.com/m/the_zero_theorem/"
# test "http://www.urbandictionary.com/define.php?term=clown%20computing"
# test "https://soundcloud.com/floatingpoints/floating-points-four-tet-final-plastic-people-2-1-2015"
# test "https://github.com/camlistore/camlistore"
# test "https://twitter.com/RonConway/status/582633100758265857"
# test "http://ix.io/i1v"
# test "http://www.twitch.tv/317070"
# test "http://www.twitch.tv/heroeswartv"
# test "https://www.youtube.com/watch?v=5aLSGeVhMjA"
# test "https://www.youtube.com/watch?v=D091idBiieY"
# test "https://www.youtube.com/watch?v=QKM4XeHJqVM"
# test "http://www.ebi.ac.uk/pdbe/entry/pdb/2d4f/citations"
# test "https://mobile.twitter.com/ByronSonne/status/641630788908400640"
# test "https://twitter.com/AccordionGuy/status/641622229705428992"
# test "https://twitter.com/wellcometrust/status/657152678263418880"
# test "https://twitter.com/ioerror/status/655020058981351424"
# test "https://www.goodreads.com/review/show/1438354031"
test "https://www.youtube.com/watch?v=8P8UKBAOfGo"