require 'epitools'
require 'open-uri'

class GoogleSuggestHandler < Marvin::CommandHandler

  exposes :suggest

  def suggest(params)
    query = params[:message]
    p query
    #json    = ["how do you", ["how do you get pink eye", "how do you delete your facebook", "how do you know", "how do you take a screenshot", "how do you take a screenshot on a mac", "how do you get married in skyrim", "how do you find the area of a circle", "how do you find the circumference of a circle", "how do you find the area of a triangle", "how do you get mono"]]
    json    = open("http://suggestqueries.google.com/complete/search?client=firefox&q=#{query.urlencode}").read.from_json
    results = json.last

    if results.empty?
      say "I'm all out of suggestions."
    else
      say results.join(" | ")
    end
  end

end