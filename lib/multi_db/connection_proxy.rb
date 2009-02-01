module MultiDb
  class ConnectionProxy
    include MultiDb::QueryCacheCompat
    include ActiveRecord::ConnectionAdapters::QueryCache
    
    # Safe methods are those that should either go to the slave ONLY or go
    # to the current active connection.
    SAFE_METHODS = [ :select_all, :select_one, :select_value, :select_values, 
      :select_rows, :select, :verify!, :raw_connection, :active?, :reconnect!,
      :disconnect!, :reset_runtime, :log, :log_info ]

    attr_accessor :master
    attr_accessor :current
    
    class << self

      # defaults to RAILS_ENV if multi_db is used with Rails
      # defaults to 'development' when used outside Rails
      attr_accessor :environment
      
      # a list of models that should always go directly to the master
      #
      # Example:
      #
      #  MultiDb::ConnectionProxy.master_models = ['CGI::Session::ActiveRecordStore']
      attr_accessor :master_models

      # Replaces the connection of ActiveRecord::Base with a proxy and
      # establishes the connections to the slaves.
      def setup!
        self.master_models ||= []
        self.environment   ||= (defined?(RAILS_ENV) ? RAILS_ENV : 'development')
        
        master = ActiveRecord::Base
        slaves = init_slaves
        raise "No slaves databases defined for environment: #{self.environment}" if slaves.empty?
        master.send :include, MultiDb::ActiveRecordExtensions
        ActiveRecord::Observer.send :include, MultiDb::ObserverExtensions
        master.connection_proxy = new(master, slaves)
        master.logger.info("** multi_db with master and #{slaves.length} slave#{"s" if slaves.length > 1} loaded.")
      end

      # Slave entries in the database.yml must be named like this
      #   development_slave_database:
      # or
      #   development_slave_database1:
      # or
      #   production_slave_database_someserver:
      # These would be available later as MultiDb::SlaveDatabaseSomeserver
      def init_slaves
        returning([]) do |slaves|
          ActiveRecord::Base.configurations.keys.each do |name|
            if name.to_s =~ /#{self.environment}_(slave_database.*)/
              MultiDb.module_eval %Q{
                class #{$1.camelize} < ActiveRecord::Base
                  self.abstract_class = true
                  establish_connection :#{name}
                end
              }, __FILE__, __LINE__
              slaves << "MultiDb::#{$1.camelize}".constantize
            end
          end
        end
      end
      
    end

    def initialize(master, slaves)
      @slaves      = Scheduler.new(slaves)
      @master      = master
      @current     = @slaves.current
      @reconnect   = false
      @with_master = 0
    end
    
    def slave
      @slaves.current
    end

    def with_master
      @current = @master
      @with_master += 1
      yield
    ensure
      @with_master -= 1
      @current = @slaves.current if @with_master == 0
    end
    
    def transaction(start_db_transaction = true, &block)
      with_master { get_connection(@current).transaction(start_db_transaction, &block) }
    end

    # Calls the method on master/slave and dynamically creates a new
    # method on success to speed up subsequent calls
    def method_missing(method, *args, &block)
      returning(send(target_method(method), method, *args, &block)) do 
        create_delegation_method!(method)
      end
    end
        
    protected

    def get_connection(db_class)
      db_class.retrieve_connection
    end

    def create_delegation_method!(method)
      self.instance_eval %Q{
        def #{method}(*args, &block)
          #{'next_reader!' unless unsafe?(method)}
          #{target_method(method)}(:#{method}, *args, &block)
        end
      }
    end
    
    def target_method(method)
      unsafe?(method) ? :send_to_master : :send_to_current
    end
    
    def send_to_master(method, *args, &block)
      reconnect_master! if @reconnect
      get_connection(@master).send(method, *args, &block)
    rescue => e
      raise_master_error(e)
    end
    
    def send_to_current(method, *args, &block)
      reconnect_master! if @reconnect && master?
      get_connection(@current).send(method, *args, &block)
    rescue NotImplementedError, NoMethodError
      raise
    rescue => e # TODO don't rescue everything
      raise_master_error(e) if master?
      logger.warn "[MULTIDB] Error reading from slave database"
      logger.error %(#{e.message}\n#{e.backtrace.join("\n")})
      @slaves.blacklist!(@current)
      next_reader!
      retry
    end
    
    def next_reader!
      return if @with_master > 0 # don't if in with_master block
      @current = @slaves.next
    rescue Scheduler::NoMoreItems
      logger.warn "[MULTIDB] All slaves are blacklisted. Reading from master"
      @current = @master
    end
    
    def reconnect_master!
      get_connection(@master).reconnect!
      @reconnect = false
    end
    
    def raise_master_error(error)
      logger.fatal "[MULTIDB] Error accessing master database. Scheduling reconnect"
      @reconnect = true
      raise error
    end
    
    def unsafe?(method)
      !SAFE_METHODS.include?(method)
    end
    
    def master?
      @current == @master
    end
        
    def logger
      ActiveRecord::Base.logger
    end
    
  end
end