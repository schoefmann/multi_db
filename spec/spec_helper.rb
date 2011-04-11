require 'rubygems'
gem 'activerecord', '3.0.5'
%w[tlattr_accessors active_record yaml erb rspec logger].each {|lib| require lib}

RAILS_ENV = ENV['RAILS_ENV'] = 'test'

MULTI_DB_SPEC_DIR = File.dirname(__FILE__)
MULTI_DB_SPEC_CONFIG = YAML::load(File.open(MULTI_DB_SPEC_DIR + '/config/database.yml'))

ActiveRecord::Base.logger = Logger.new(MULTI_DB_SPEC_DIR + "/debug.log")
ActiveRecord::Base.configurations = MULTI_DB_SPEC_CONFIG