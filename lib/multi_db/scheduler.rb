module MultiDb
  class Scheduler
    class NoMoreItems < Exception; end
    
    attr :items
    delegate :[], :[]=, :to => :items
    
    def initialize(items, blacklist_timeout = 1.minute)
      @n = items.length
      @items     = items
      @blacklist = Array.new(@n, Time.at(0))
      @current   = 0
      @blacklist_timeout = blacklist_timeout
    end
    
    def blacklist!(item)
      @blacklist[@items.index(item)] = Time.now
    end
    
    def current
      @items[@current]
    end
    
    def next
      previous = @current
      until(@blacklist[next_index!] < Time.now - @blacklist_timeout) do
        raise NoMoreItems, 'All items are blacklisted' if @current == previous
      end
      @items[@current]
    end
    
    protected
    
    def next_index!
      @current = (@current + 1) % @n
    end
    
  end
end
