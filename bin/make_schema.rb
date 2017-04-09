#!/usr/bin/env ruby

require 'json'
require 'yaml'
require 'comicvine/mongo'

objects = {}
cur_obj = nil
File.readlines('/Users/homans/code/comicvine-mongo/lib/comicvine/mongo.rb').each do |line|
  if line =~ /class\s+(\w+)\s+\<\s+ComicVine\:\:Resource/
    cur_obj = $1.to_s.downcase
    objects[cur_obj] = []
  elsif !cur_obj.nil? && line =~ /field|belongs_to|has_and_belongs_to_many|has_many|has_one/
    array = line.split(',').map { |a| a.split(' ') }
    objects[cur_obj].push array
  else
    #line unless line =~ /^\s+$|^\s+#|\s+(def|self|end|if|els|super|\!)/
  end
end

# Gather a count of each property
data = {
    props: {},
    prop_groups: {},
    class_map: {}
}

objects.each do |k, v|
  v.each do |prop|
    field = prop.first.last
    data[:props][field] = {type: nil, count: 0} unless data[:props].has_key? field
    data[:props][field][:count] += 1

    # Store in class map
    data[:class_map][k] = {} unless data[:class_map].has_key? k

    # gather type
    prop.each do |a|
      if a[0] =~ /type|class_name/
        data[:props][field][:type] = a[1]
        data[:class_map][k][field] = {type: a[1], data: prop}
      end
    end
  end
end


# Group the most used properties for separate types
5.times do |n|
  count = objects.count - n
  data[:prop_groups][count] = []

  data[:props].each do |k, v|
    if v[:count].eql? count
      data[:prop_groups][count].push k.to_s
    end
  end
end

# Create RAML Types
dir = '/Users/homans/code/comicvine_api/schemas/'

data[:class_map].keys.sort.each do |klass|
  raml_schema = {
      klass => {
          'id' => 'integer',
          'comic_vine' => 'CVResource',

      }
  }

  data[:class_map][klass].keys.sort.each do |prop|
    name = prop.delete(':')

    # Skip comicvine comon values
    if %w(site_detail_url api_detail_url id date_added has_staff_review image).include? name
      next
    end
    raml_schema[klass][name] = {}

    if data[:class_map][klass][prop][:type] =~ /Integer|String|Array/
      raml_schema[klass][name] = data[:class_map][klass][prop][:type].downcase
    elsif data[:class_map][klass][prop][:type] =~ /ComicVine::Resource::(\w+)/
      relation = data[:class_map][klass][prop][:data].first.first

      if relation =~ /has_and_belongs_to_many|has_many/
        raml_schema[klass][name] = 'ApiResource'
      elsif relation =~ /belongs_to|has_one/
        raml_schema[klass][name] = 'ApiResources'
      end

    elsif data[:class_map][klass][prop][:type] == 'DateTime'
      raml_schema[klass][name] = 'datetime-only'
    elsif data[:class_map][klass][prop][:type] == 'Date'
      raml_schema[klass][name] = 'date-only'
    elsif data[:class_map][klass][prop][:type] == 'Hash' && name == 'image'
      raml_schema[klass][name] = 'Image'
    else
      #puts "#{klass} : #{prop} => #{data[:class_map][klass][prop][:type]}"
    end
  end

  yaml = {
#      klass.to_s.capitalize => {
          'type' => 'object',
          'properties' => raml_schema[klass]
#      }
  }.to_yaml
  #puts yaml
  File.write("#{dir}#{klass}.yml", yaml)
  puts "  #{klass.to_s.capitalize}: !include schemas/#{klass}.yml"
end

#ComicVine::API.get_details(:issue, 6).save!
#ComicVine::API.get_details(:volume, 1487).save!
#ComicVine::API.get_details(:character, 1253).save!
#ComicVine::API.get_details(:concept, 35070).save!
#ComicVine::API.get_details(:location, 21766).save!
#ComicVine::API.get_details(:movie, 1).save!
#ComicVine::API.get_details(:object, 15073).save!
#ComicVine::API.get_details(:origin, 3).save!
#ComicVine::API.get_details(:person, 1251).save!
#ComicVine::API.get_details(:power, 1).save!
#ComicVine::API.get_details(:promo, 1637).save!
#ComicVine::API.get_details(:publisher, 4).save!
#ComicVine::API.get_details(:series, 1).save!
#ComicVine::API.get_details(:story_arc, 27758).save!
#ComicVine::API.get_details(:team, 40426).save!


#puts data.to_json

