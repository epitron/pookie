* Size limit for downloads
  * Switch to https://github.com/tarcieri/http gem

* Make a class that Pry pries into
  * root of "connections.yml" is the friendly name
  * generate a method for each server friendly name
  * "servers"/"bots" object (ostruct)
  * "{dis,re,}connect(alias)" method

* Logger plugin

* bot.pry should have each server as a method (eg: freenode, efnet, etc.) so you can "freenode.join" or "cd efnet"

* Bot#inspect should show: #<Bot server=host:port (ssl)>

* Kill log spam:
  [2014/04/07 04:52:24.856] !! [New thread] 
  [2014/04/07 04:52:15.172] !! [Thread done]

* Kill mechanize spam

* Automatic cinch plugin loader (requires)

* Automatically add PSYC friends
  => [2014/04/07 03:37:16.237] >> :psyced.org NOTICE pookie :epi kindly asks for your friendship.
  => How do we get the xmpp: name?

* Plugin installing/uninstalling/reloading from CLI

* Curses interface
  Features:
    - no config file necessary -- use /server to connect
    - settings saved to yaml automatically
  Architecture:
    - 2 Panes
      => Logger goes to main pane
      => Input line goes to Pry

