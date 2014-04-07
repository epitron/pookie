require 'yaml'
require 'pp'

config = YAML.load(open("connections.yml"))
defaults = config.delete("defaults")

pp config
p defaults: defaults
