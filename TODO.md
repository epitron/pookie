* Logger plugin

* Bot#inspect shows #<Bot server=host:port (ssl)>

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

