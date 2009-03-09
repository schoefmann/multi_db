require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require MULTI_DB_SPEC_DIR + '/../lib/multi_db/thread_local_accessors'
require MULTI_DB_SPEC_DIR + '/../lib/multi_db/scheduler'

describe MultiDb::Scheduler do
  
  before do
    @items = [5, 7, 4, 8]
    @scheduler = MultiDb::Scheduler.new(@items.clone)
  end
  
  it "should return items in a round robin fashion" do
    first = @items.shift
    @scheduler.current.should == first
    @items.each do |item|
      @scheduler.next.should == item
    end
    @scheduler.next.should == first
  end
  
  it 'should not return blacklisted items' do
    @scheduler.blacklist!(4)
    @items.size.times do
      @scheduler.next.should_not == 4
    end
  end
  
  it 'should raise NoMoreItems if all are blacklisted' do
    @items.each do |item|
      @scheduler.blacklist!(item)
    end
    lambda {
      @scheduler.next
    }.should raise_error(MultiDb::Scheduler::NoMoreItems)
  end
  
  it 'should unblacklist items automatically' do
    @scheduler = MultiDb::Scheduler.new(@items.clone, 1.second)
    @scheduler.blacklist!(7)
    sleep(1)
    @scheduler.next.should == 7
  end

  describe '(accessed from multiple threads)' do

    it '#current and #next should return the same item for the same thread' do
      @scheduler.current.should == 5
      @scheduler.next.should == 7
      Thread.new do
        @scheduler.current.should == 5
        @scheduler.next.should == 7
      end.join
      @scheduler.next.should == 4
    end

  end
  
end

