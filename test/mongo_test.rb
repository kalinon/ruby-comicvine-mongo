require 'test_helper'

class MongoTest < Minitest::Test

  def test_that_it_has_a_version_number
    refute_nil ::ComicVine::Mongo::VERSION
  end

  def test_mongo_save_issue
    assert @api.get_details(:issue, 6).save!
  end

  def test_mongo_save_volume
    assert @api.get_details(:volume, 51951).save!
  end

  def test_mongo_save_character
    assert @api.get_details(:character, 1253).save!
  end

  def test_mongo_save_concept
    assert @api.get_details(:concept, 35070).save!
  end

  def test_mongo_save_location
    assert @api.get_details(:location, 21766).save!
  end

  def test_mongo_save_movie
    assert @api.get_details(:movie, 1).save!
  end

  def test_mongo_save_object
    assert @api.get_details(:object, 15073).save!
  end

  def test_mongo_save_origin
    assert @api.get_details(:origin, 3).save!
  end

  def test_mongo_save_person
    assert @api.get_details(:person, 1251).save!
  end

  def test_mongo_save_power
    assert @api.get_details(:power, 1).save!
  end

  def test_mongo_save_promo
    assert @api.get_details(:promo, 1637).save!
  end

  def test_mongo_save_publisher
    assert @api.get_details(:publisher, 4).save!
  end

  def test_mongo_save_series
    assert @api.get_details(:series, 1).save!
  end

  def test_mongo_save_story_arc
    assert @api.get_details(:story_arc, 27758).save!
  end

  def test_mongo_save_team
    assert @api.get_details(:team, 40426).save!
  end

  def test_cv_fetch_and_save

    p = @api.get_details(:person, 2756)

    resp = @api.get_list(:issues, limit: 5)
    resp.each do |issue|
      refute_nil issue.volume
      issue.fetch!
      refute_nil issue.volume
      assert issue.save!
    end
  end

  def test_save_children
    obj = @api.get_details(:issue, 6)
    refute_nil obj
    assert obj.save!
    #assert obj.save_assoc!
  end

  def test_volume_has_issues
    obj = @api.get_details(:volume, 91273)

    refute_nil obj
    assert obj.save!
    assert obj.issues.all.count > 0
  end
end