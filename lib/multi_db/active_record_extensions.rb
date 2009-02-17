module MultiDb
  module ActiveRecordExtensions
    def self.included(base)
      base.alias_method_chain :reload, :master

      class << base
        
        cattr_accessor :connection_proxy

        # hijack the original method
        def connection
          if ConnectionProxy.master_models.include?(self.to_s)
            self.retrieve_connection
          else
            self.connection_proxy
          end
        end
      end

    end
    
    def reload_with_master(*args, &block)
      self.class.connection_proxy.with_master do
        reload_without_master(*args, &block)
      end
    end
  end
end