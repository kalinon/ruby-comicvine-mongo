require 'comicvine/mongo/version'
require 'comicvine'
require 'mongoid'

## Yardoc macros
# @!macro [new] return.sub_resources
#   @return [ Resource::Character, Resource::Concept, Resource::Episode, Resource::Issue, Resource::Location, Resource::Movie, Resource::Object, Resource::Origin, Resource::Person, Resource::Power, Resource::Promo, Resource::Publisher, Resource::Series, Resource::StoryArc, Resource::Team, Resource::Volume ]

module ComicVine

  ##
  # Module to hold our mongoid specific methods and overrides for {ComicVine::Resource}
  # @since 0.1.0
  module Mongo
    ##
    # Replaces the default {ComicVine::Resource::initialize} function, allowing us to create mongo enabled classes
    # @since 0.1.0
    def initialize(args)

      args.each do |k, v|

        # Convert sub arrays to objects
        v.collect! { |i| ComicVine::Resource::create_resource(i) } if v.kind_of?(Array) && !v.empty? && v.first.key?('api_detail_url')

        # Convert sub hashes to objects
        if v.kind_of?(Hash) && v.key?('api_detail_url')
          v = ComicVine::Resource::create_resource(v)
        end

        # Set the instance variable to value
        args[k] = v
      end
      #puts args.to_json
      super
    end

    ##
    # Cycles through associated id's on the object and loads/fetches the child/parent objects and saves them to mongo
    # @since 0.1.0
    def save_assoc!
      # Identify methods that end in id or ids
      self.methods.each do |attr|
        # Match attribute ids
        next if attr !~ /^(?!_)([\w\d\_]+)(_ids?)$/

        # endings with ids imply multiple
        if attr =~ /^(?!_)([\w\d\_]+)(_ids)$/
          assoc = $1.to_s.pluralize.to_sym

          next if self.reflect_on_association(assoc).nil?

          meta = self.reflect_on_association(assoc)
          self.method(attr).call.each do |id|
            obj = self._fetch_by_assoc_and_id(meta, id)
            obj.fetch!.save! unless obj.nil?
          end
        elsif attr =~ /^(?!_)([\w\d\_]+)(_id)$/
          assoc = $1.to_s.to_sym

          next if self.reflect_on_association(assoc).nil?

          meta = self.reflect_on_association(assoc)
          obj = self._fetch_by_assoc_and_id(meta, self.method(attr).call)
          obj.fetch!.save! unless obj.nil?
        else
          next
        end
      end
    end

    ##
    # Will parse the relation metadata to identify the class and resource type. A check is performed to see if it is saved in the mongodb, if so it will then load it. It will then query ComicVine::API for the latest information, and return the resource
    # @param meta [Mongoid::Relations::Metadata]
    # @param id [Integer]
    # @macro return.sub_resources
    # @since 0.1.0
    def _fetch_by_assoc_and_id(meta, id)
      if Object.class_eval(meta.class_name).where(id: id).exists?
        Object.class_eval(meta.class_name).find(id)
      else
        type = meta.class_name.demodulize.underscore.to_sym

        if ComicVine::API.find_detail(type).nil?
          nil
        else
          resource_name = ComicVine::API.find_detail(type)['detail_resource_name'].to_sym

          begin
            ComicVine::API.get_details(resource_name, id)
          rescue ComicVine::API::ComicVineAPIError
            return nil
          end

        end
      end
    end

    ##
    # Method to fetch info from ComicVine and save
    # @return [ComicVine::Resource]
    # @since 0.1.5
    def fetch_and_update!
      fetch!
      save!
      self
    end

    ##
    # Method to fetch info from ComicVine and save assoc objects
    # @return [ComicVine::Resource]
    # @since 0.1.5
    def fetch_and_update_assoc!
      fetch!
      save!
      save_assoc!
      self
    end

  end

  class Resource

    ##
    # Takes hash and returns a {http://www.rubydoc.info/github/mongoid/mongoid/Mongoid/Document Mongoid::Document} subclass of {ComicVine::Resource} based on identified type
    #
    # @example
    #   ComicVine::Resource.create_resource(hash) #=> #<ComicVine::Resource::Issue:0x007fa6a427bbe8>
    #
    # @param attr [Hash]
    # @macro return.sub_resources
    # @since 0.1.0
    def self.create_resource(attr)
      type = ComicVine::Resource::identify_and_update_response(attr)

      if type

        # if its a review the api doesnt actually exist, so return the hash
        return attr if type.equal? :review

        c = Object.class_eval('ComicVine::Resource::' + type.to_s.camelcase)

        if c.where(id: attr['id']).exists?
          c.find(attr['id'])
        else
          c.new attr
        end
      else
        raise ScriptError, 'Unknown type for api_detail_url: ' + attr['api_detail_url']
      end
    end


    ##
    # Extends {ComicVine::Resource::Issue} to add mongoid functions
    # @since 0.1.2
    class Issue < ComicVine::Resource
      include Mongoid::Document
      include ComicVine::Mongo
      include Mongoid::Attributes::Dynamic

      field :aliases, type: String
      field :api_detail_url, type: String
      field :cover_date, type: Date
      field :date_added, type: DateTime
      field :date_last_updated, type: DateTime
      field :deck, type: String
      field :description, type: String
      field :has_staff_review, type: Hash
      field :id, type: Integer
      field :image, type: Hash
      field :issue_number, type: String
      field :name, type: String
      field :site_detail_url, type: String
      field :store_date, type: Date

      ##
      # Accounts for ComicVine's miss-match return of false if no review exists. Sets an empty hash
      # @param value [Hash]
      # @since 0.1.0
      def has_staff_review=(value)
        if value.nil? || value.kind_of?(FalseClass)
          self.has_staff_review = {}
        else
          super
        end
      end

      ##
      # @return [true, false]
      def has_staff_review?
        !self.has_staff_review.empty?
      end


      belongs_to :volume, class_name: 'ComicVine::Resource::Volume', inverse_of: :issues, optional: true

      has_many :first_appearance_teams, class_name: 'ComicVine::Resource::Team', inverse_of: :first_appeared_in_issue, validate: false
      has_and_belongs_to_many :team_credits, class_name: 'ComicVine::Resource::Team', inverse_of: :issue_credits, validate: false
      has_and_belongs_to_many :team_disbanded_in, class_name: 'ComicVine::Resource::Team', inverse_of: :issues_disbanded_in, validate: false

      has_many :first_appearance_characters, class_name: 'ComicVine::Resource::Character', inverse_of: :first_appeared_in_issue, validate: false
      has_and_belongs_to_many :character_credits, class_name: 'ComicVine::Resource::Character', inverse_of: :issue_credits, validate: false
      has_and_belongs_to_many :character_died_in, class_name: 'ComicVine::Resource::Character', inverse_of: :issues_died_in, validate: false

      has_many :first_appearance_concepts, class_name: 'ComicVine::Resource::Concept', inverse_of: :first_appeared_in_issue, validate: false
      has_and_belongs_to_many :concept_credits, class_name: 'ComicVine::Resource::Concept', inverse_of: :issue_credits, validate: false

      has_many :first_appearance_objects, class_name: 'ComicVine::Resource::Object', inverse_of: :first_appeared_in_issue, validate: false
      has_and_belongs_to_many :object_credits, class_name: 'ComicVine::Resource::Object', inverse_of: :issue_credits, validate: false

      has_many :first_appearance_storyarcs, class_name: 'ComicVine::Resource::StoryArc', inverse_of: :first_appeared_in_issue, validate: false
      has_and_belongs_to_many :story_arc_credits, class_name: 'ComicVine::Resource::StoryArc', inverse_of: :issues, validate: false

      has_many :first_appearance_locations, class_name: 'ComicVine::Resource::Location', inverse_of: :first_appeared_in_issue, validate: false
      has_and_belongs_to_many :location_credits, class_name: 'ComicVine::Resource::Location', inverse_of: :issue_credits, validate: false

      has_and_belongs_to_many :person_credits, class_name: 'ComicVine::Resource::Person', inverse_of: :issue_credits, validate: false
    end

    ##
    # Extends {ComicVine::Resource::Volume} to add mongoid functions
    # @since 0.1.2
    class Volume < ComicVine::Resource
      include Mongoid::Document
      include ComicVine::Mongo
      include Mongoid::Attributes::Dynamic

      field :aliases, type: String
      field :api_detail_url, type: String
      field :count_of_issues, type: Integer
      field :date_added, type: DateTime
      field :date_last_updated, type: DateTime
      field :deck, type: String
      field :description, type: String
      field :id, type: Integer
      field :image, type: Hash
      field :name, type: String
      field :site_detail_url, type: String
      field :start_year, type: Integer

      has_and_belongs_to_many :teams, class_name: 'ComicVine::Resource::Team', inverse_of: :volume_credits, validate: false
      has_and_belongs_to_many :characters, class_name: 'ComicVine::Resource::Character', inverse_of: :volume_credits, validate: false
      has_and_belongs_to_many :concepts, class_name: 'ComicVine::Resource::Concept', inverse_of: :volume_credits, validate: false

      has_many :issues, class_name: 'ComicVine::Resource::Issue', inverse_of: :volume, validate: false
      embeds_one :first_issue, class_name: 'ComicVine::Resource::Issue', validate: false, cascade_callbacks: true
      embeds_one :last_issue, class_name: 'ComicVine::Resource::Issue', validate: false, cascade_callbacks: true

      has_and_belongs_to_many :locations, class_name: 'ComicVine::Resource::Location', inverse_of: :volume_credits, validate: false
      has_and_belongs_to_many :objects, class_name: 'ComicVine::Resource::Object', inverse_of: :volume_credits, validate: false
      has_and_belongs_to_many :people, class_name: 'ComicVine::Resource::Person', inverse_of: :volume_credits, validate: false

      belongs_to :publisher, class_name: 'ComicVine::Resource::Publisher', inverse_of: :volumes, validate: false, optional: true


      ##
      # Will save child {Issues} then pass to super
      #
      # @example Save the document.
      #   document.save!
      #
      # @param [ Hash ] options Options to pass to the save.
      #
      # @raise [ Errors::Validations ] If validation failed.
      # @raise [ Errors::Callback ] If a callback returns false.
      #
      # @return [ true, false ] True if validation passed.
      #
      # @since 0.1.6
      def save!(options = {})
        self.issues.each { |i| i.save }
        super
      end

      ##
      # Will save child {Issues} then pass to super
      #
      # @example Save the document.
      #   document.save
      #
      # @param [ Hash ] options Options to pass to the save.
      #
      # @return [ true, false ] True is success, false if not.
      #
      # @since 0.1.6
      def save(options = {})
        self.issues.each { |i| i.save }
        super
      end

    end

    ##
    # Extends {ComicVine::Resource::Character} to add mongoid functions
    # # @since 0.1.2
    class Character < ComicVine::Resource
      include Mongoid::Document
      include ComicVine::Mongo
      include Mongoid::Attributes::Dynamic

      field :aliases, type: String
      field :api_detail_url, type: String
      field :date_added, type: DateTime
      field :date_last_updated, type: DateTime
      field :deck, type: String
      field :description, type: String
      field :id, type: Integer
      field :image, type: Hash
      field :name, type: String
      field :site_detail_url, type: String
      field :birth, type: String
      field :count_of_issue_appearances, type: Integer
      field :real_name, type: String
      field :gender, type: Integer

      has_and_belongs_to_many :character_enemies, class_name: 'ComicVine::Resource::Character', inverse_of: nil, validate: false
      has_and_belongs_to_many :character_friends, class_name: 'ComicVine::Resource::Character', inverse_of: nil, validate: false

      belongs_to :origin, class_name: 'ComicVine::Resource::Origin', inverse_of: :characters, validate: false, optional: true

      has_and_belongs_to_many :creators, class_name: 'ComicVine::Resource::Person', inverse_of: :created_characters, validate: false

      belongs_to :first_appeared_in_issue, class_name: 'ComicVine::Resource::Issue', inverse_of: :first_appearance_characters, validate: false, optional: true
      has_and_belongs_to_many :issue_credits, class_name: 'ComicVine::Resource::Issue', inverse_of: :character_credits, validate: false
      has_and_belongs_to_many :issues_died_in, class_name: 'ComicVine::Resource::Issue', inverse_of: :character_died_in, validate: false

      has_and_belongs_to_many :movies, class_name: 'ComicVine::Resource::Movie', inverse_of: :characters, validate: false
      has_and_belongs_to_many :powers, class_name: 'ComicVine::Resource::Power', inverse_of: :characters, validate: false

      belongs_to :publisher, class_name: 'ComicVine::Resource::Publisher', inverse_of: :characters, validate: false, optional: true
      has_and_belongs_to_many :story_arc_credits, class_name: 'ComicVine::Resource::StoryArc', inverse_of: :characters, validate: false

      has_and_belongs_to_many :team_enemies, class_name: 'ComicVine::Resource::Team', inverse_of: nil, validate: false
      has_and_belongs_to_many :team_friends, class_name: 'ComicVine::Resource::Team', inverse_of: nil, validate: false
      has_and_belongs_to_many :teams, class_name: 'ComicVine::Resource::Team', inverse_of: :characters, validate: false

      has_and_belongs_to_many :volume_credits, class_name: 'ComicVine::Resource::Volume', inverse_of: :characters, validate: false

      accepts_nested_attributes_for :origin, :publisher, :first_appeared_in_issue, validate: false
    end

    ##
    # Extends {ComicVine::Resource::Concept} to add mongoid functions
    # @since 0.1.2
    class Concept < ComicVine::Resource
      include Mongoid::Document
      include ComicVine::Mongo
      include Mongoid::Attributes::Dynamic

      field :aliases, type: String
      field :api_detail_url, type: String
      field :date_added, type: DateTime
      field :date_last_updated, type: DateTime
      field :deck, type: String
      field :description, type: String
      field :id, type: Integer
      field :image, type: Hash
      field :name, type: String
      field :site_detail_url, type: String
      field :count_of_issue_appearances, type: Integer
      field :start_year, type: Integer

      ##
      # Accounts for ComicVine's miss-spelling of issue in key. Maps count_of_isssue_appearances to count_of_issue_appearances
      # @param value [Integer]
      # @since 0.1.0
      def count_of_isssue_appearances=(value)
        self[:count_of_issue_appearances] = value
      end

      ##
      # Accounts for ComicVine's miss-spelling of issue in key. returns count_of_issue_appearances
      # @return [Integer]
      # @since 0.1.0
      def count_of_isssue_appearances
        self[:count_of_issue_appearances]
      end

      belongs_to :first_appeared_in_issue, class_name: 'ComicVine::Resource::Issue', inverse_of: :first_appearance_concepts, validate: false, optional: true
      has_and_belongs_to_many :issue_credits, class_name: 'ComicVine::Resource::Issue', inverse_of: :concept_credits, validate: false
      has_and_belongs_to_many :movies, class_name: 'ComicVine::Resource::Movie', inverse_of: :concept_credits, validate: false
      has_and_belongs_to_many :volume_credits, class_name: 'ComicVine::Resource::Volume', inverse_of: :concepts, validate: false

    end

    ##
    # Extends {ComicVine::Resource::Episode} to add mongoid functions
    # @since 0.1.2
    class Episode < ComicVine::Resource
      include Mongoid::Document
      include ComicVine::Mongo
      include Mongoid::Attributes::Dynamic

      field :aliases, type: String
      field :api_detail_url, type: String
      field :date_added, type: DateTime
      field :date_last_updated, type: DateTime
      field :deck, type: String
      field :description, type: String
      field :id, type: Integer
      field :image, type: Hash
      field :name, type: String
      field :site_detail_url, type: String
      field :has_staff_review, type: Hash
      field :episode_number, type: Integer
      field :air_date, type: Date

      ##
      # Accounts for ComicVine's miss-match return of false if no review exists. Sets an empty hash
      # @param value [Hash]
      # @since 0.1.0
      def has_staff_review=(value)
        if value.nil? || value.kind_of?(FalseClass)
          self.has_staff_review = {}
        else
          super
        end
      end

      ##
      # @return [true, false]
      def has_staff_review?
        !self.has_staff_review.empty?
      end


      has_and_belongs_to_many :character_credits, class_name: 'ComicVine::Resource::Character', inverse_of: nil, validate: false
      has_and_belongs_to_many :characters_died_in, class_name: 'ComicVine::Resource::Character', inverse_of: nil, validate: false
      has_and_belongs_to_many :concept_credits, class_name: 'ComicVine::Resource::Concept', inverse_of: nil, validate: false

      has_many :first_appearance_characters, class_name: 'ComicVine::Resource::Character', inverse_of: nil, validate: false
      has_many :first_appearance_concepts, class_name: 'ComicVine::Resource::Concept', inverse_of: nil, validate: false
      has_many :first_appearance_locations, class_name: 'ComicVine::Resource::Location', inverse_of: nil, validate: false
      has_many :first_appearance_objects, class_name: 'ComicVine::Resource::Object', inverse_of: nil, validate: false
      has_many :first_appearance_storyarcs, class_name: 'ComicVine::Resource::StoryArc', inverse_of: :first_appeared_in_episode, validate: false
      has_many :first_appearance_teams, class_name: 'ComicVine::Resource::Team', inverse_of: nil, validate: false
      has_many :first_appearance_locations, class_name: 'ComicVine::Resource::Location', inverse_of: nil, validate: false

      has_and_belongs_to_many :location_credits, class_name: 'ComicVine::Resource::Location', inverse_of: nil, validate: false
      has_and_belongs_to_many :object_credits, class_name: 'ComicVine::Resource::Object', inverse_of: nil, validate: false
      has_and_belongs_to_many :person_credits, class_name: 'ComicVine::Resource::Person', inverse_of: nil, validate: false
      has_and_belongs_to_many :team_credits, class_name: 'ComicVine::Resource::Team', inverse_of: nil, validate: false

      has_and_belongs_to_many :story_arc_credits, class_name: 'ComicVine::Resource::StoryArc', inverse_of: :episodes, validate: false
      belongs_to :series, class_name: 'ComicVine::Resource::Series', inverse_of: :episodes, validate: false, optional: true
    end

    ##
    # Extends {ComicVine::Resource::Location} to add mongoid functions
    # @since 0.1.2
    class Location < ComicVine::Resource
      include Mongoid::Document
      include ComicVine::Mongo
      include Mongoid::Attributes::Dynamic

      field :aliases, type: String
      field :api_detail_url, type: String
      field :count_of_issue_appearances, type: Integer
      field :date_added, type: DateTime
      field :date_last_updated, type: DateTime
      field :deck, type: String
      field :description, type: String
      field :id, type: Integer
      field :image, type: Hash
      field :name, type: String
      field :site_detail_url, type: String
      field :start_year, type: Integer

      belongs_to :first_appeared_in_issue, class_name: 'ComicVine::Resource::Issue', inverse_of: :first_appearance_locations, validate: false, optional: true
      has_and_belongs_to_many :issue_credits, class_name: 'ComicVine::Resource::Issue', inverse_of: :location_credits, validate: false

      has_and_belongs_to_many :movies, class_name: 'ComicVine::Resource::Movie', inverse_of: :location_credits, validate: false
      has_and_belongs_to_many :story_arc_credits, class_name: 'ComicVine::Resource::StoryArc', inverse_of: nil, validate: false
      has_and_belongs_to_many :volume_credits, class_name: 'ComicVine::Resource::Volume', inverse_of: :locations, validate: false
    end

    ##
    # Extends {ComicVine::Resource::Movie} to add mongoid functions
    # @since 0.1.2
    class Movie < ComicVine::Resource
      include Mongoid::Document
      include ComicVine::Mongo
      include Mongoid::Attributes::Dynamic

      field :api_detail_url, type: String
      field :box_office_revenue, type: Integer
      field :budget, type: Integer
      field :date_added, type: DateTime
      field :date_last_updated, type: DateTime
      field :deck, type: String
      field :description, type: String
      field :id, type: Integer
      field :image, type: Hash
      field :name, type: String
      field :site_detail_url, type: String
      field :release_date, type: DateTime
      field :rating, type: String
      field :has_staff_review, type: Hash
      field :total_revenue, type: Integer
      field :runtime, type: Integer
      field :distributor, type: String

      ##
      # Accounts for ComicVine's miss-match return of false if no review exists. Sets an empty hash
      # @param value [Hash]
      # @since 0.1.0
      def has_staff_review=(value)
        if value.nil? || value.kind_of?(FalseClass)
          self.has_staff_review = {}
        else
          super
        end
      end

      ##
      # @return [true, false]
      def has_staff_review?
        !self.has_staff_review.empty?
      end

      has_and_belongs_to_many :studios, class_name: 'ComicVine::Resource::Publisher', inverse_of: nil, validate: false
      has_and_belongs_to_many :concepts, class_name: 'ComicVine::Resource::Concept', inverse_of: nil, validate: false
      has_and_belongs_to_many :locations, class_name: 'ComicVine::Resource::Location', inverse_of: nil, validate: false
      has_and_belongs_to_many :writers, class_name: 'ComicVine::Resource::Person', inverse_of: nil, validate: false
      has_and_belongs_to_many :producers, class_name: 'ComicVine::Resource::Person', inverse_of: nil, validate: false
      has_and_belongs_to_many :teams, class_name: 'ComicVine::Resource::Team', inverse_of: :movies, validate: false
      has_and_belongs_to_many :objects, class_name: 'ComicVine::Resource::Object', inverse_of: :movies, validate: false
      has_and_belongs_to_many :story_arc_credits, class_name: 'ComicVine::Resource::StoryArc', inverse_of: :movies, validate: false
      has_and_belongs_to_many :characters, class_name: 'ComicVine::Resource::Character', inverse_of: :movies, validate: false

    end

    ##
    # Extends {ComicVine::Resource::Object} to add mongoid functions
    # @since 0.1.2
    class Object < ComicVine::Resource
      include Mongoid::Document
      include ComicVine::Mongo
      include Mongoid::Attributes::Dynamic

      field :aliases, type: String
      field :api_detail_url, type: String
      field :count_of_issue_appearances, type: Integer
      field :date_added, type: DateTime
      field :date_last_updated, type: DateTime
      field :deck, type: String
      field :description, type: String
      field :id, type: Integer
      field :image, type: Hash
      field :name, type: String
      field :site_detail_url, type: String
      field :start_year, type: Integer

      belongs_to :first_appeared_in_issue, class_name: 'ComicVine::Resource::Issue', inverse_of: :first_appearance_characters, validate: false, optional: true
      has_and_belongs_to_many :issue_credits, class_name: 'ComicVine::Resource::Issue', inverse_of: :object_credits, validate: false
      has_and_belongs_to_many :movies, class_name: 'ComicVine::Resource::Movie', inverse_of: :objects, validate: false
      has_and_belongs_to_many :story_arc_credits, class_name: 'ComicVine::Resource::StoryArc', inverse_of: :objects, validate: false
      has_and_belongs_to_many :volume_credits, class_name: 'ComicVine::Resource::Volume', inverse_of: :objects, validate: false
    end

    ##
    # Extends {ComicVine::Resource::Origin} to add mongoid functions
    # @since 0.1.2
    class Origin < ComicVine::Resource
      include Mongoid::Document
      include ComicVine::Mongo
      include Mongoid::Attributes::Dynamic

      field :api_detail_url, type: String
      field :character_set, type: String
      field :id, type: Integer
      field :name, type: String
      field :profiles, type: Array
      field :site_detail_url, type: String

      has_many :characters, class_name: 'ComicVine::Resource::Character', inverse_of: :origin, validate: false

    end

    ##
    # Extends {ComicVine::Resource::Person} to add mongoid functions
    # @since 0.1.2
    class Person < ComicVine::Resource
      include Mongoid::Document
      include ComicVine::Mongo
      include Mongoid::Attributes::Dynamic

      field :aliases, type: String
      field :api_detail_url, type: String
      field :birth, type: Date
      field :death, type: Date
      field :count_of_issue_appearances, type: Integer
      field :country, type: String
      field :date_added, type: DateTime
      field :date_last_updated, type: DateTime
      field :deck, type: String
      field :description, type: String
      field :email, type: String
      field :id, type: Integer
      field :gender, type: Integer
      field :image, type: Hash
      field :name, type: String
      field :site_detail_url, type: String
      field :website, type: String
      field :role, type: String

      ##
      # Override to handle ComicVine hash results
      # @param value [DateTime]
      # @since 0.1.0
      def death=(value)
        if value.nil?
          # Do nothing
        elsif value.kind_of?(Hash) && value.has_key?('date')
          # Translate the string
          #TODO: Parse the remaining keys: timezone_type && timezone into correct dateTime. See person: 2756
          super DateTime.parse(value['date'])
        elsif value.kind_of?(DateTime)
          super
        end
      end

      ##
      # Accounts for ComicVine's miss-spelling of issue in key. Maps count_of_isssue_appearances to count_of_issue_appearances
      # @param value [Integer]
      # @since 0.1.0
      def count_of_isssue_appearances=(value)
        self[:count_of_issue_appearances] = value
      end

      ##
      # Accounts for ComicVine's miss-spelling of issue in key. returns count_of_issue_appearances
      # @return [Integer]
      # @since 0.1.0
      def count_of_isssue_appearances
        self[:count_of_issue_appearances]
      end

      has_one :hometown, class_name: 'ComicVine::Resource::Location', validate: false
      has_and_belongs_to_many :created_characters, class_name: 'ComicVine::Resource::Character', inverse_of: :creators, validate: false
      has_and_belongs_to_many :issues, class_name: 'ComicVine::Resource::Issue', inverse_of: :person_credits, validate: false
      has_and_belongs_to_many :story_arc_credits, class_name: 'ComicVine::Resource::StoryArc', inverse_of: :person_credits, validate: false
      has_and_belongs_to_many :volume_credits, class_name: 'ComicVine::Resource::Volume', inverse_of: :people, validate: false

    end

    ##
    # Extends {ComicVine::Resource::Power} to add mongoid functions
    # @since 0.1.2
    class Power < ComicVine::Resource
      include Mongoid::Document
      include ComicVine::Mongo
      include Mongoid::Attributes::Dynamic

      field :aliases, type: String
      field :api_detail_url, type: String
      field :name, type: String
      field :site_detail_url, type: String
      field :id, type: Integer
      field :description, type: String
      field :date_added, type: DateTime
      field :date_last_updated, type: DateTime
      has_and_belongs_to_many :characters, class_name: 'ComicVine::Resource::Character', inverse_of: :powers, validate: false
    end

    ##
    # Extends {ComicVine::Resource::Promo} to add mongoid functions
    # @since 0.1.2
    class Promo < ComicVine::Resource
      include Mongoid::Document
      include ComicVine::Mongo
      include Mongoid::Attributes::Dynamic

      field :api_detail_url, type: String
      field :date_added, type: DateTime
      field :deck, type: String
      field :id, type: Integer
      field :image, type: Hash
      field :link, type: String
      field :name, type: String
      field :resource_type, type: String
      field :user, type: String
    end

    ##
    # Extends {ComicVine::Resource::Publisher} to add mongoid functions
    # @since 0.1.2
    class Publisher < ComicVine::Resource
      include Mongoid::Document
      include ComicVine::Mongo
      include Mongoid::Attributes::Dynamic

      field :aliases, type: String
      field :api_detail_url, type: String
      field :date_added, type: DateTime
      field :date_last_updated, type: DateTime
      field :deck, type: String
      field :description, type: String
      field :id, type: Integer
      field :image, type: Hash
      field :name, type: String
      field :site_detail_url, type: String
      field :location_address, type: String
      field :location_city, type: String
      field :location_state, type: String

      has_many :characters, class_name: 'ComicVine::Resource::Character', inverse_of: :publisher, validate: false
      has_many :story_arcs, class_name: 'ComicVine::Resource::StoryArc', inverse_of: :publisher, validate: false
      has_many :teams, class_name: 'ComicVine::Resource::Team', inverse_of: :publisher, validate: false
      has_many :volumes, class_name: 'ComicVine::Resource::Volume', inverse_of: :publisher, validate: false
      has_many :series, class_name: 'ComicVine::Resource::Series', inverse_of: :publisher, validate: false

      ##
      # Will save children then pass to super
      #
      # @example Save the document.
      #   document.save!
      #
      # @param [ Hash ] options Options to pass to the save.
      #
      # @raise [ Errors::Validations ] If validation failed.
      # @raise [ Errors::Callback ] If a callback returns false.
      #
      # @return [ true, false ] True if validation passed.
      #
      # @since 0.1.6
      def save!(options = {})
        self.characters.each { |i| i.save }
        self.story_arcs.each { |i| i.save }
        self.teams.each { |i| i.save }
        self.volumes.each { |i| i.save }
        self.series.each { |i| i.save }

        super
      end

      ##
      # Will save children then pass to super
      #
      # @example Save the document.
      #   document.save
      #
      # @param [ Hash ] options Options to pass to the save.
      #
      # @return [ true, false ] True is success, false if not.
      #
      # @since 0.1.6
      def save(options = {})
        self.characters.each { |i| i.save }
        self.story_arcs.each { |i| i.save }
        self.teams.each { |i| i.save }
        self.volumes.each { |i| i.save }
        self.series.each { |i| i.save }
        super
      end

    end

    ##
    # Extends {ComicVine::Resource::Series} to add mongoid functions
    # @since 0.1.2
    class Series < ComicVine::Resource
      include Mongoid::Document
      include ComicVine::Mongo
      include Mongoid::Attributes::Dynamic

      field :aliases, type: String
      field :api_detail_url, type: String
      field :date_added, type: DateTime
      field :date_last_updated, type: DateTime
      field :deck, type: String
      field :description, type: String
      field :id, type: Integer
      field :image, type: Hash
      field :name, type: String
      field :site_detail_url, type: String

      field :count_of_episodes, type: Integer
      field :start_year, type: Integer

      has_and_belongs_to_many :characters, class_name: 'ComicVine::Resource::Character', inverse_of: nil, validate: false

      has_many :episodes, class_name: 'ComicVine::Resource::Episode', inverse_of: :series, validate: false
      embeds_one :first_episode, class_name: 'ComicVine::Resource::Episode', validate: false, cascade_callbacks: true
      embeds_one :last_episode, class_name: 'ComicVine::Resource::Episode', validate: false, cascade_callbacks: true

      has_and_belongs_to_many :location_credits, class_name: 'ComicVine::Resource::Location', inverse_of: nil, validate: false
      belongs_to :publisher, class_name: 'ComicVine::Resource::Publisher', inverse_of: :series, validate: false, optional: true

      ##
      # Will save children then pass to super
      #
      # @example Save the document.
      #   document.save!
      #
      # @param [ Hash ] options Options to pass to the save.
      #
      # @raise [ Errors::Validations ] If validation failed.
      # @raise [ Errors::Callback ] If a callback returns false.
      #
      # @return [ true, false ] True if validation passed.
      #
      # @since 0.1.6
      def save!(options = {})
        self.episodes.each { |i| i.save }

        super
      end

      ##
      # Will save children then pass to super
      #
      # @example Save the document.
      #   document.save
      #
      # @param [ Hash ] options Options to pass to the save.
      #
      # @return [ true, false ] True is success, false if not.
      #
      # @since 0.1.6
      def save(options = {})
        self.episodes.each { |i| i.save }

        super
      end
    end

    ##
    # Extends {ComicVine::Resource::StoryArc} to add mongoid functions
    # @since 0.1.2
    class StoryArc < ComicVine::Resource
      include Mongoid::Document
      include ComicVine::Mongo
      include Mongoid::Attributes::Dynamic

      field :aliases, type: String
      field :api_detail_url, type: String
      field :date_added, type: DateTime
      field :date_last_updated, type: DateTime
      field :deck, type: String
      field :description, type: String
      field :id, type: Integer
      field :image, type: Hash
      field :name, type: String
      field :site_detail_url, type: String

      field :count_of_issue_appearances, type: Integer

      def count_of_isssue_appearances=(value)
        self[:count_of_isssue_appearances] = value
      end

      def count_of_isssue_appearances
        self[:count_of_isssue_appearances]
      end


      belongs_to :publisher, class_name: 'ComicVine::Resource::Publisher', inverse_of: :story_arcs, validate: false, optional: true

      belongs_to :first_appeared_in_issue, class_name: 'ComicVine::Resource::Issue', inverse_of: :first_appearance_storyarcs, validate: false, optional: true
      has_and_belongs_to_many :issues, class_name: 'ComicVine::Resource::Issue', inverse_of: :story_arc_credits, validate: false

      has_and_belongs_to_many :movies, class_name: 'ComicVine::Resource::Movie', inverse_of: :story_arc_credits, validate: false
      has_and_belongs_to_many :teams, class_name: 'ComicVine::Resource::Team', inverse_of: :story_arc_credits, validate: false
      has_and_belongs_to_many :characters, class_name: 'ComicVine::Resource::Character', inverse_of: :story_arc_credits, validate: false

      belongs_to :first_appeared_in_episode, class_name: 'ComicVine::Resource::Episode', inverse_of: :first_appearance_storyarcs, validate: false, optional: true
      has_and_belongs_to_many :episodes, class_name: 'ComicVine::Resource::Episode', inverse_of: :story_arc_credits, validate: false
    end

    ##
    # Extends {ComicVine::Resource::Team} to add mongoid functions
    # @since 0.1.2
    class Team < ComicVine::Resource
      include Mongoid::Document
      include ComicVine::Mongo
      include Mongoid::Attributes::Dynamic

      field :aliases, type: String
      field :api_detail_url, type: String
      field :date_added, type: DateTime
      field :date_last_updated, type: DateTime
      field :deck, type: String
      field :description, type: String
      field :id, type: Integer
      field :image, type: Hash
      field :name, type: String
      field :site_detail_url, type: String
      field :count_of_issue_appearances, type: Integer
      field :count_of_team_members, type: Integer

      def count_of_isssue_appearances=(value)
        self[:count_of_isssue_appearances] = value
      end

      def count_of_isssue_appearances
        self[:count_of_isssue_appearances]
      end

      def disbanded_in_issues=(value)
        if value.kind_of? ComicVine::Resource::Issue
          self.issues_disbanded_in << value
        elsif value.kind_of? Array
          self.issues_disbanded_in = value
        end
      end

      def disbanded_in_issues
        self.issues_disbanded_in
      end

      def isssues_disbanded_in=(value)
        if value.kind_of? ComicVine::Resource::Issue
          self.issues_disbanded_in << value
        elsif value.kind_of? Array
          self.issues_disbanded_in = value
        end
      end

      def isssues_disbanded_in
        self.issues_disbanded_in
      end

      has_and_belongs_to_many :character_enemies, class_name: 'ComicVine::Resource::Character', inverse_of: nil, validate: false
      has_and_belongs_to_many :character_friends, class_name: 'ComicVine::Resource::Character', inverse_of: nil, validate: false
      has_and_belongs_to_many :characters, class_name: 'ComicVine::Resource::Character', inverse_of: :teams, validate: false

      belongs_to :first_appeared_in_issue, class_name: 'ComicVine::Resource::Issue', inverse_of: :first_appearance_teams, validate: false, optional: true
      has_and_belongs_to_many :issue_credits, class_name: 'ComicVine::Resource::Issue', inverse_of: :team_credits, validate: false
      has_and_belongs_to_many :issues_disbanded_in, class_name: 'ComicVine::Resource::Issue', inverse_of: :team_disbanded_in, validate: false

      belongs_to :publisher, class_name: 'ComicVine::Resource::Publisher', inverse_of: :teams, validate: false, optional: true
      has_and_belongs_to_many :movies, class_name: 'ComicVine::Resource::Movie', inverse_of: :teams, validate: false
      has_and_belongs_to_many :story_arc_credits, class_name: 'ComicVine::Resource::StoryArc', inverse_of: :teams, validate: false
      has_and_belongs_to_many :volume_credits, class_name: 'ComicVine::Resource::Volume', inverse_of: :teams, validate: false

    end

  end
end
