$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

ENV['RACK_ENV'] = 'test'

require 'comicvine/mongo'
require 'minitest/autorun'
require 'minitest/reporters'

Mongoid.load!(File.join(File.expand_path('..', __FILE__), 'mongo.yml'), ENV['RACK_ENV'])

MiniTest::Reporters.use!

module Minitest::Assertions
  def assert_nothing_raised(*)
    yield
  end
end