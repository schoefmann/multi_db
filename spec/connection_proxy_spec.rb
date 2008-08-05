require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require MULTI_DB_SPEC_DIR + '/../lib/multi_db/query_cache_compat'
require MULTI_DB_SPEC_DIR + '/../lib/multi_db/active_record_extensions'
require MULTI_DB_SPEC_DIR + '/../lib/multi_db/observer_extensions'
require MULTI_DB_SPEC_DIR + '/../lib/multi_db/scheduler'
require MULTI_DB_SPEC_DIR + '/../lib/multi_db/connection_proxy'

RAILS_ROOT = MULTI_DB_SPEC_DIR
RAILS_DEFAULT_LOGGER = ActiveRecord::Base.logger

describe MultiDb::ConnectionProxy do
  
  before(:all) do
    ActiveRecord::Base.establish_connection(MULTI_DB_SPEC_CONFIG['test'])
    MultiDb::ConnectionProxy.setup!
    @proxy = ActiveRecord::Base.connection
    @sql = 'SELECT 1 + 1 FROM DUAL'
  end

  it "should generate classes for each entry in the database.yml" do
    defined?(MultiDb::SlaveDatabase1).should_not be_nil
    defined?(MultiDb::SlaveDatabase2).should_not be_nil
  end
  
  it 'should handle nested with_master-blocks correctly' do
    @proxy.current.should_not == @proxy.master
    @proxy.with_master do
      @proxy.current.should == @proxy.master
      @proxy.with_master do
        @proxy.current.should == @proxy.master
        @proxy.with_master do
          @proxy.current.should == @proxy.master
        end
        @proxy.current.should == @proxy.master
      end
      @proxy.current.should == @proxy.master
    end
    @proxy.current.should_not == @proxy.master
  end
  
  it 'should perform transactions on the master' do
    @proxy.master.should_receive(:select_all).exactly(1) # makes sure the first one goes to a slave
    @proxy.select_all(@sql)
    ActiveRecord::Base.transaction do
      @proxy.select_all(@sql)
    end
  end
  
  it 'should switch to the next reader on selects' do
    MultiDb::SlaveDatabase1.connection.should_receive(:select_one).twice
    MultiDb::SlaveDatabase2.connection.should_receive(:select_one).twice
    4.times { @proxy.select_one(@sql) }
  end
  
  it 'should not switch to the next reader when whithin a with_master-block' do
    @proxy.master.should_receive(:select_one).twice
    MultiDb::SlaveDatabase1.connection.should_not_receive(:select_one)
    MultiDb::SlaveDatabase2.connection.should_not_receive(:select_one)
    @proxy.with_master do
      2.times { @proxy.select_one(@sql) }
    end
  end
  
  it 'should send dangerous methods to the master' do
    meths = [:insert, :update, :delete, :execute]
    meths.each do |meth|
      MultiDb::SlaveDatabase1.connection.stub!(meth).and_raise(RuntimeError)
      @proxy.master.should_receive(meth).and_return(true)
      @proxy.send(meth, @sql)
    end
  end
  
  it 'should dynamically generate safe methods' do
    @proxy.should_not respond_to(:select_value)
    @proxy.select_value(@sql)
    @proxy.should respond_to(:select_value)
  end
  
  it 'should cache queries using select_all' do
    ActiveRecord::Base.cache do
      # next_reader will be called and switch to the SlaveDatabase2
      MultiDb::SlaveDatabase2.connection.should_receive(:select_all).exactly(1)
      MultiDb::SlaveDatabase1.connection.should_not_receive(:select_all)
      @proxy.master.should_not_receive(:select_all)
      3.times { @proxy.select_all(@sql) }
    end
  end
  
  it 'should invalidate the cache on insert, delete and update' do
    ActiveRecord::Base.cache do
      meths = [:insert, :update, :delete]
      meths.each do |meth|
        @proxy.master.should_receive(meth).and_return(true)
      end
      MultiDb::SlaveDatabase2.connection.should_receive(:select_all).twice
      MultiDb::SlaveDatabase1.connection.should_receive(:select_all).once
      3.times do |i|
        @proxy.select_all(@sql)
        @proxy.send(meths[i])
      end
    end
  end
  
  it 'should retry the next slave when one fails and finally fall back to the master' do
    MultiDb::SlaveDatabase1.connection.should_receive(:select_all).once.and_raise(RuntimeError)
    MultiDb::SlaveDatabase2.connection.should_receive(:select_all).once.and_raise(RuntimeError)
    @proxy.master.should_receive(:select_all).and_return(true)
    @proxy.select_all(@sql)
  end
  
  it 'should try to reconnect the master connection after the master has failed' do
    @proxy.master.should_receive(:update).and_raise(RuntimeError)
    lambda { @proxy.update(@sql) }.should raise_error
    @proxy.master.should_receive(:reconnect!).and_return(true)
    @proxy.master.should_receive(:insert).and_return(1)
    @proxy.insert(@sql)
  end
  
end

