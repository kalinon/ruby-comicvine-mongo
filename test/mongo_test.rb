require 'test_helper'

class MongoTest < Minitest::Test

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup

  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.
  def teardown
    Mongoid.purge!
  end

  def test_that_it_has_a_version_number
    refute_nil ::ComicVine::Mongo::VERSION
  end

  def test_comicvine
    hash = JSON.parse('{"aliases":null,"api_detail_url":"http://comicvine.gamespot.com/api/issue/4000-6/","cover_date":"1952-10-01","date_added":"2008-06-06 11:10:16","date_last_updated":"2015-07-11 12:08:20","deck":null,"description":"<p>The horrors of:</p><p>- Lost race!</p><p>- The man germ!</p><p>- Man in the hood!</p><p>- The things!</p><p>-Stories behind the stars, featuring the legendary battle between Hercules, Hydra and Iolaus!</p><p>Plus, two page long prose-stories.</p>","has_staff_review":false,"id":6,"image":{"icon_url":"http://comicvine.gamespot.com/api/image/square_avatar/2645776-chamber_of_chills__13_cgc_8.5.jpg","medium_url":"http://comicvine.gamespot.com/api/image/scale_medium/2645776-chamber_of_chills__13_cgc_8.5.jpg","screen_url":"http://comicvine.gamespot.com/api/image/screen_medium/2645776-chamber_of_chills__13_cgc_8.5.jpg","small_url":"http://comicvine.gamespot.com/api/image/scale_small/2645776-chamber_of_chills__13_cgc_8.5.jpg","super_url":"http://comicvine.gamespot.com/api/image/scale_large/2645776-chamber_of_chills__13_cgc_8.5.jpg","thumb_url":"http://comicvine.gamespot.com/api/image/scale_avatar/2645776-chamber_of_chills__13_cgc_8.5.jpg","tiny_url":"http://comicvine.gamespot.com/api/image/square_mini/2645776-chamber_of_chills__13_cgc_8.5.jpg"},"issue_number":"13","name":"The Lost Race","site_detail_url":"http://comicvine.gamespot.com/chamber-of-chills-magazine-13-the-lost-race/4000-6/","store_date":null,"volume":{"api_detail_url":"http://comicvine.gamespot.com/api/volume/4050-1487/","id":1487,"name":"Chamber of Chills Magazine","site_detail_url":"http://comicvine.gamespot.com/chamber-of-chills-magazine/4050-1487/"}}')
    assert_kind_of Hash, hash
    type = ComicVine::Resource.identify_type(hash['api_detail_url'])
    assert_equal :issue, type

    assert_nothing_raised do
      obj = ComicVine::Resource::create_resource hash
      assert_kind_of ComicVine::Resource, obj
      assert_kind_of ComicVine::Resource::Issue, obj
    end
  end

  def test_mongo_save
    #assert ComicVine::API.get_details(:issue, 6).save!
    #assert ComicVine::API.get_details(:volume, 1487).save!
    #assert ComicVine::API.get_details(:character, 1253).save!
    #assert ComicVine::API.get_details(:concept, 35070).save!
    #assert ComicVine::API.get_details(:location, 21766).save!
    #assert ComicVine::API.get_details(:movie, 1).save!
    #assert ComicVine::API.get_details(:object, 15073).save!
    #assert ComicVine::API.get_details(:origin, 3).save!
    #assert ComicVine::API.get_details(:person, 1251).save!
    #assert ComicVine::API.get_details(:power, 1).save!
    #assert ComicVine::API.get_details(:promo, 1637).save!
    #assert ComicVine::API.get_details(:publisher, 4).save!
    #assert ComicVine::API.get_details(:series, 1).save!
    #assert ComicVine::API.get_details(:story_arc, 27758).save!
    #assert ComicVine::API.get_details(:team, 40426).save!
  end

  def test_cv_fetch_and_save

    p = ComicVine::API.get_details(:person, 2756)

    resp = ComicVine::API.get_list(:issues, limit: 5)
    resp.each do |issue|
      refute_nil issue.volume
      issue.fetch!
      refute_nil issue.volume
      assert issue.save!
    end
  end

  def test_save_children
    obj = ComicVine::API.get_details(:issue, 6)
    refute_nil obj
    assert obj.save!
    assert obj.save_assoc!
  end
end