require 'bundler/gem_tasks'
require 'rake/testtask'
require 'yard'
require 'dotenv/load'

# Test tasks
Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
  t.warning = false
end

YARD::Rake::YardocTask.new do |t|
  begin
    require 'yard-mongoid'
  rescue LoadError => e
    puts 'Could not require yard-mongoid'
  end

  t.files = ['lib/**/*.rb'] # optional
  t.options = %w{--private} # optional
  t.stats_options = ['--list-undoc'] # optional
end

# Default task
task :default => :test

task :console do
  require 'irb'
  require 'irb/completion'
  require 'comicvine/mongo' # You know what to do.

  Mongoid.load!(File.join(File.expand_path('..', __FILE__), 'test', 'mongo.yml'), ENV['RACK_ENV'])

  ARGV.clear
  IRB.start
end

Rake::Task['build'].enhance do
  require 'digest/sha2'
  built_gem_path = 'pkg/comicvine-mongo-'+ComicVine::Mongo::VERSION+'.gem'
  checksum = Digest::SHA256.new.hexdigest(File.read(built_gem_path))
  checksum_path = 'checksum/comicvine-mongo-'+ComicVine::Mongo::VERSION+'.gem.sha256'
  File.open(checksum_path, 'w') { |f| f.write(checksum) }
end
