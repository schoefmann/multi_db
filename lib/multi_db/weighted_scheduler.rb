module MultiDb
  class WeightedScheduler < Scheduler
    
    def total_weight
      @total_weight ||= items.sum{|slave| slave::WEIGHT }
    end
    
  protected
    
    def next_index!
      # self.current_index = super if total_weight == 2
      rnd_idx = rand(total_weight)
      # puts "Using rnd_idx: #{rnd_idx}, current_index: #{current_index}<br>"
      self.current_index = items.index(items.detect do |slave|
        rnd_idx -= slave::WEIGHT
        true if rnd_idx < 0
      end)
    end
    
  end
end

