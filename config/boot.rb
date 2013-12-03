require 'rubygems'
require 'marvin'

root = Pathname.new(__FILE__).dirname.join("..").expand_path
Marvin::Settings.root = root
