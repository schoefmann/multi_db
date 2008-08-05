module MultiDb
  module ActiveRecordExtensions
    def self.included(base)
      base.alias_method_chain :reload, :master
    end
    
    def reload_with_master(*args, &block)
      connection.with_master { reload_without_master }
    end
  end
end