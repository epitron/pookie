require 'cinch'
require 'yaml'
require 'thread'
require 'pp'

require_relative 'plugins/url_titles'

config   = YAML.load(open("config/connections.yml"))
defaults = config.delete("defaults")

pp defaults: defaults
pp config: config

bots = config.map do |address, options|
  ssl = options.delete("ssl")

  bot = Cinch::Bot.new do
    # see: http://rubydoc.info/gems/cinch/file/docs/bot_options.md
    configure do |c|
      c.server  = address
      c.ssl.use = true if ssl

      defaults.merge(options).each do |key, val|
        c.send("#{key}=", val)
      end

      c.plugins.plugins = [Cinch::Plugins::URLTitles]
    end
  end

  Dir.mkdir "logs" unless File.directory? "logs"

  bot.loggers << Cinch::Logger::FormattedLogger.new(File.open("logs/debug.log", "a"))
  bot.loggers.level = :debug
  bot.loggers.first.level  = :log

  bot
end

threads = bots.map do |bot|
  Thread.new { bot.start }
end

commands = {
  "ls" => proc do
    bots.each_with_index do |bot,n|
      puts "#{n}: #{bot.config.server}:#{bot.config.port} (ssl: #{bot.config.ssl.use})"
      puts "   #{bot.channels.map(&:name).join(", ")}"
    end
  end,

  "join"  => proc { |n, c| bots[n.to_i].join(c) },
  "part"  => proc { |n, c| bots[n.to_i].part(c) },
  "quit"  => proc { |n| bots[n.to_i].quit },
  "start" => proc { |n| threads << Thread.new { bots[n.to_i].start } },
}

## CLI
# require 'readline'

# loop do
#   line = Readline.readline("> ")

#   command, args = line.split

#   if block = commands[command]
#     block.call(*args)
#   end
# end

## Easy CLI
require 'pry'
Pry.config.should_load_rc = false
Pry.config.should_load_local_rc = false
binding.pry

