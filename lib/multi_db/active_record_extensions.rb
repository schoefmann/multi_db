module MultiDb
  module ActiveRecordExtensions
    def self.included(base)
      base.alias_method_chain :reload, :master

      class << base
        def connection_proxy=(proxy)
          @@connection_proxy = proxy
        end
        
        # hijack the original method
        def connection
          @@connection_proxy
        end
      end
      
    end
    
    def reload_with_master(*args, &block)
      connection.with_master { reload_without_master }
    end
  end
end