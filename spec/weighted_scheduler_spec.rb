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
    @proxy      = ActiveRecord::Base.connection_proxy
    @scheduler  = @proxy.scheduler
    
    @master = @proxy.master.retrieve_connection
  end

  describe "total weight of all slaves" do
    it "knows the total weight of all slaves" do
      @scheduler.total_weight.should == 26
    end

    it "caches the total weight" do
      @scheduler.should_receive(:items).once.and_return([MultiDb::SlaveDatabase1])
      @scheduler.total_weight
      @scheduler.total_weight
      @scheduler.total_weight
    end
  end
  
  describe "distributes queries according to weight" do
    
    it "next_index! distributes the queries according to weight" do
      n = 100_000
      # Fire off pretend queries
      queries = n.times.map do
        @scheduler.send( :next_index! )
      end
      
      # Count queries and group by the index the slave machine has 
      queries.inject({}){|hsh, idx|
        hsh[idx].nil? ? hsh[idx] = 1 : hsh[idx] += 1
        hsh
      }.each do |slave_idx, query_count|
        # for large number of queries (> 10 000), the distribution is proportional to the weights. For 100k 'queries', we're accurate to one decimal.
        weight_portion  = (@scheduler.items[slave_idx]::WEIGHT/@scheduler.total_weight.to_f).round(1)
        query_portion   = (query_count/n.to_f).round(1)
        
        weight_portion.should == query_portion
      end
    end
  end
end