# ComicVine::Mongo

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/comicvine/mongo`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'comicvine-mongo'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install comicvine-mongo

You additionally will need to set up your ComicVine Api key [[See the comicvine gem page](https://github.com/kalinon/ruby-comicvine-api)] as well as set up your mongoid connection [[See mongoid documentaion](https://docs.mongodb.com/ruby-driver/master/tutorials/6.0.0/mongoid-installation/#configuration)]

```ruby
# Example config
ComicVine::API.api_key = '18357f40df87fb4a4aa6bbbb27cd8ad1deb08d3e'
Mongoid.load!('/path/to/mongo.yml', :env_name)
```
## Usage

You can use the same syntax used with the comicvine gem to interact with the api. Now, however, you functions will return a resource subclass appropriate for the api call

```ruby
ComicVine::API.get_details(:issue, 6) #=> ComicVine::Resource::Issue
```

These are subclasses of ComicVine::Resource and are each a [Mongoid::Document](http://www.rubydoc.info/github/mongoid/mongoid/Mongoid/Document). Here are the current subclasses:

> Character, Concept, Episode, Issue, Location, Movie, Object, Origin, Person, Power, Promo, Publisher, Series, StoryArc, Team, Volume

Here is some example usages:

```ruby
# Gather an issue from the api
issue = ComicVine::API.get_details(:issue, 6)
# You can then save the issue
issue.save!
# You can also then save its parent and children objects (i.e Publisher, Characters, etc)
issue.save_assoc!

# You can also query objects that were saved via Mongoid
pub = ComicVine::Resource::Publisher.find(4)
# To update the object with newest API information or to fill missing children/parent relations
pub.fetch!
# Then you can save your changes
pub.save!
pub.save_assoc!
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `gem install comicvine`. Or you can download it from https://rubygems.org/gems/comicvine-mongo

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kalinon/ruby-comicvine-mongo.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

