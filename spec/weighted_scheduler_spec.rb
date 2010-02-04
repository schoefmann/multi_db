require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require MULTI_DB_SPEC_DIR + '/../lib/multi_db/query_cache_compat'
require MULTI_DB_SPEC_DIR + '/../lib/multi_db/active_record_extensions'
require MULTI_DB_SPEC_DIR + '/../lib/multi_db/observer_extensions'
require MULTI_DB_SPEC_DIR + '/../lib/multi_db/connection_proxy'
require MULTI_DB_SPEC_DIR + '/../lib/multi_db/scheduler'
require MULTI_DB_SPEC_DIR + '/../lib/multi_db/weighted_scheduler'

RAILS_ROOT = MULTI_DB_SPEC_DIR

describe MultiDb::WeightedScheduler do
  
  before(:each) do
    ActiveRecord::Base.configurations = YAML::load(File.open(MULTI_DB_SPEC_DIR + '/config/database.yml'))
    ActiveRecord::Base.establish_connection :test
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Migration.create_table(:master_models, :force => true) {}
    class MasterModel < ActiveRecord::Base; end
    ActiveRecord::Migration.create_table(:foo_models, :force => true) {|t| t.string :bar}
    class FooModel < ActiveRecord::Base; end
    @sql = 'SELECT 1 + 1 FROM DUAL'
  end
  
  before(:each) do
    MultiDb::ConnectionProxy.master_models = ['MasterModel']
    MultiDb::ConnectionProxy.setup!(MultiDb::WeightedScheduler)
    @proxy = ActiveRecord::Base.connection_proxy
  end

  after(:each) do
    ActiveRecord::Base.send :alias_method, :reload, :reload_without_master
  end
  
  it "knows the total weight of all slaves" do
    @proxy.scheduler.total_weight.should == 15
  end
end
