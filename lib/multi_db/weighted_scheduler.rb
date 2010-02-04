module MultiDb
  class WeightedScheduler < Scheduler
    
    def total_weight
      items.sum{|slave| slave::WEIGHT }
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