require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require MULTI_DB_SPEC_DIR + '/../lib/multi_db/thread_local_accessors.rb'

class Foo
  extend MultiDb::ThreadLocalAccessors
  tlattr_accessor :bar
end

describe MultiDb::ThreadLocalAccessors do

  it "should store values local to the thread" do
    x = Foo.new
    x.bar = 2
    Thread.new do
      x.bar.should == 2
      x.bar = 3
      Thread.new do
        x.bar.should == 2
        x.bar = 5
      end.join
      x.bar.should == 3
    end.join
    x.bar.should == 2
  end

  it 'should not leak memory' do
    x = Foo.new
    n = 6000
    # create many thread-local values to make sure GC is invoked
    n.times do
      Thread.new do
        x.bar = rand
      end.join
    end
    hash = x.send :instance_variable_get, '@_tlattr_bar'
    hash.size.should < (n / 2) # it should be a lot lower than n!
  end

end

