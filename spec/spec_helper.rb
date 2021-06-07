require 'rubygems'

%w[rspec tlattr_accessors mysql2 active_record yaml erb rspec logger].each {|lib| require lib}

require 'rails/observers/activerecord/active_record'

module Rails
  def self.env
    ActiveSupport::StringInquirer.new("test")
  end
end

MULTI_DB_SPEC_DIR = File.dirname(__FILE__)
MULTI_DB_SPEC_CONFIG = YAML::load(File.open(MULTI_DB_SPEC_DIR + '/config/database.yml'))

ActiveRecord::Base.logger = Logger.new(MULTI_DB_SPEC_DIR + "/debug.log")
ActiveRecord::Base.configurations = MULTI_DB_SPEC_CONFIG

RSpec.configure do |config|
  config.tty = true
  config.color = true
end
