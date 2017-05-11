$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

ENV['RACK_ENV'] = 'test'

require 'comicvine/mongo'
require 'minitest/autorun'

Mongoid.load!(File.join(File.expand_path('..', __FILE__), 'mongo.yml'), ENV['RACK_ENV'])

require 'minitest/reporters'
MiniTest::Reporters.use!

require 'minitest-vcr'
VCR.configure do |c|
  c.cassette_library_dir = 'test/cassettes'
  c.hook_into :webmock
  c.filter_sensitive_data('{CV_API_KEY}') { ENV['CV_API_KEY'] }
end
MinitestVcr::Spec.configure!

module Minitest::Assertions
  def assert_nothing_raised(*)
    yield
  end
end

class Minitest::Test

  def setup
    @api = ComicVine::API.new(ENV['CV_API_KEY'])
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.
  def teardown
    Mongoid.purge!
  end

  def before_setup
    VCR.insert_cassette File.join(self.class.to_s, name), record: :new_episodes
  end

  def after_teardown
    VCR.eject_cassette
  end
end