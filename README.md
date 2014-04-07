# pookie

An IRC bot that does one thing:

* Displays information about URLs that people paste on IRC.

It can connect to many IRC channels on many servers within one process, can extract titles and ratings from YouTube videos, can display information about things without titles (like image resolution, zip file sizes, etc.), can show Tweets directly, and more!
 
## Installing/Running

To install/run pookie:

1. Get the code (`git clone http://github.com/epitron/pookie.git`)
2. Run bundler (`bundle install`)
3. Copy `config/connections.yml-default` to `config/connections.yml`, and edit it to configure what channels/networks pookie connects to.
4. Edit `config/settings.yml` (to name your bot)
5. Run `./go`!
  
## Copyright

Copyright (c) 2009-2014 epitron

## License

Licensed under the WTFPL2. (See LICENSE for details.)
