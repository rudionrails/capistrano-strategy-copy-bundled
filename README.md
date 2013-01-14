# Capistrano Strategy: Copy Bundled

This recipe for capistrano utilizes the regular copy strategy. However,
instead of bundling the gems on the remote servers, they are already
pre-bundled on the deploy machine and sent as one package.

In some networks, due to security reasons, production servers are not
allowed to access the internal company network. When that is the case,
you are not able access your internally written gems. Also, those kind
of servers usually, and intentionally, have no version control installed
or are behind a firewall with blocked access to rubygems, github, etc.

This capistrano recipe tries to help out with that.


## Installation

System wide usage

```console
gem install 'capistrano-strategy-copy-bundled'
```

In your Gemfile

```ruby
gem 'capistrano-strategy-copy-bundled'
```


## Usage

As this recipe does it's own bundling, there is not need to: `require 'bundler/capistrano'`.

All you have to do in your `config/deploy.rb`:

```ruby
require 'capistrano-strategy-copy-bundled'
set :deploy_via,    :copy_bundled           # bundle gems locally and send them packed to all servers
```

Additionally to that, you can set the usual options when using the regular :copy strategy for capistrano, like:

```ruby
set :copy_dir,      "/tmp/#{application}"   # path where files are temporarily put before sending them to the servers
set :copy_exclude,  ".git*"                 # we exclude the .git repo so that nobody is able to temper with the release

#Callback triggers to add your own steps within (in order)
on 'strategy:before:bundle',      'some:custom:task'
on 'strategy:after:bundle',       'some:custom:task'
on 'strategy:before:compression', 'some:custom:task'
on 'strategy:after:compression',  'some:custom:task'
on 'strategy:before:distribute',  'some:custom:task'
on 'strategy:after:distribute',   'some:custom:task'
```

Copyright &copy; 2011-2012 Rudolf Schmidt. Released under the MIT license.

