module MultiDb
  class Scheduler
    class NoMoreItems < Exception; end
    extend ThreadLocalAccessors

    attr :items
    delegate :[], :[]=, :to => :items
    tlattr_accessor :current_index, true

    def initialize(items, blacklist_timeout = 1.minute)
      @n = items.length
      @items     = items
      @blacklist = Array.new(@n, Time.at(0))
      @blacklist_timeout = blacklist_timeout
      self.current_index = 0
    end

    def blacklist!(item)
      @blacklist[@items.index(item)] = Time.now
    end

    def current
      @items[current_index]
    end

    def next
      previous = current_index
      until(@blacklist[next_index!] < Time.now - @blacklist_timeout) do
        raise NoMoreItems, 'All items are blacklisted' if current_index == previous
      end
      current
    end

    protected

    def next_index!
      self.current_index = (current_index + 1) % @n
    end
  end
end
