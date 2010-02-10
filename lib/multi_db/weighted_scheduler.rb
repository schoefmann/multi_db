module MultiDb
  class WeightedScheduler < Scheduler
    
    def total_weight
      @total_weight ||= items.sum{|slave| slave::WEIGHT }
    end
    
  protected
    
    def next_index!
      rnd_idx = rand(total_weight)
      self.current_index = items.index(items.detect do |slave|
        rnd_idx -= slave::WEIGHT
        true if rnd_idx < 0
      end)
    end
    
  end
end

