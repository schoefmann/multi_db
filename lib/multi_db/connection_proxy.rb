require 'active_record/connection_adapters/abstract/query_cache'

module MultiDb
  class ConnectionProxy
    include ActiveRecord::ConnectionAdapters::QueryCache
    include QueryCacheCompat
    extend ThreadLocalAccessors
    
    # Safe methods are those that should either go to the slave ONLY or go
    # to the current active connection.
    SAFE_METHODS = [ :select_all, :select_one, :select_value, :select_values, 
      :select_rows, :select, :verify!, :raw_connection, :active?, :reconnect!,
      :disconnect!, :reset_runtime, :log, :log_info ]

    if ActiveRecord.const_defined?(:SessionStore) # >= Rails 2.3
      DEFAULT_MASTER_MODELS = ['ActiveRecord::SessionStore::Session']
    else # =< Rails 2.3
      DEFAULT_MASTER_MODELS = ['CGI::Session::ActiveRecordStore::Session']
    end

    attr_accessor :master
    tlattr_accessor :master_depth, :current, true
    
    class << self

      # defaults to Rails.env if multi_db is used with Rails
      # defaults to 'development' when used outside Rails
      attr_accessor :environment
      
      # a list of models that should always go directly to the master
      #
      # Example:
      #
      #  MultiDb::ConnectionProxy.master_models = ['MySessionStore', 'PaymentTransaction']
      attr_accessor :master_models

      # decides if we should switch to the next reader automatically.
      # If set to false, an after|before_filter in the ApplicationController
      # has to do this.
      # This will not affect failover if a master is unavailable.
      attr_accessor :sticky_slave
      
      # if master should be the default db
      attr_accessor :defaults_to_master

      # Replaces the connection of ActiveRecord::Base with a proxy and
      # establishes the connections to the slaves.
      def setup!(scheduler = Scheduler)
        self.master_models ||= DEFAULT_MASTER_MODELS
        self.environment   ||= (defined?(Rails) ? Rails.env : 'development')
        self.sticky_slave  ||= false
        
        master = ActiveRecord::Base
        slaves = init_slaves
        raise "No slaves databases defined for environment: #{self.environment}" if slaves.empty?
        master.send :include, MultiDb::ActiveRecordExtensions
        ActiveRecord::Observer.send :include, MultiDb::ObserverExtensions
        master.connection_proxy = new(master, slaves, scheduler)
        master.logger.info("** multi_db with master and #{slaves.length} slave#{"s" if slaves.length > 1} loaded.")
      end
      
      protected

      # Slave entries in the database.yml must be named like this
      #   development_slave_database:
      # or
      #   development_slave_database1:
      # or
      #   production_slave_database_someserver:
      # These would be available later as MultiDb::SlaveDatabaseSomeserver
      def init_slaves
        [].tap do |slaves|
          ActiveRecord::Base.configurations.each do |name, values|
            if name.to_s =~ /#{self.environment}_(slave_database.*)/
              weight  = if values['weight'].blank?
                          1
                        else
                          (v=values['weight'].to_i.abs).zero?? 1 : v
                        end
              MultiDb.module_eval %Q{
                class #{$1.camelize} < ActiveRecord::Base
                  self.abstract_class = true
                  establish_connection :#{name}
                  WEIGHT = #{weight} unless const_defined?('WEIGHT')
                end
              }, __FILE__, __LINE__
              slaves << "MultiDb::#{$1.camelize}".constantize
            end
          end
        end
      end

      private :new
      
    end

    def initialize(master, slaves, scheduler = Scheduler)
      @slaves    = scheduler.new(slaves)
      @master    = master
      @reconnect = false
      @query_cache = {}
      if self.class.defaults_to_master
        self.current = @master
        self.master_depth = 1
      else
        self.current = @slaves.current
        self.master_depth = 0
      end
    end

    def slave
      @slaves.current
    end
    
    def scheduler
      @slaves
    end
    
    
    def with_master
      self.current = @master
      self.master_depth += 1
      yield
    ensure
      self.master_depth -= 1
      self.current = slave if (master_depth <= 0) 
    end
  
  
    def with_slave
      self.current = slave
      self.master_depth -= 1
      yield
    ensure
      self.master_depth += 1
      self.current = @master if (master_depth > 0)
    end
    
    def transaction(start_db_transaction = true, &block)
      with_master { @master.retrieve_connection.transaction(start_db_transaction, &block) }
    end

    # Calls the method on master/slave and dynamically creates a new
    # method on success to speed up subsequent calls
    def method_missing(method, *args, &block)
      send(target_method(method), method, *args, &block).tap do 
        create_delegation_method!(method)
      end
    end

    # Switches to the next slave database for read operations.
    # Fails over to the master database if all slaves are unavailable.
    def next_reader!
      return if  master_depth > 0  # don't if in with_master block
      self.current = @slaves.next
    rescue Scheduler::NoMoreItems
      logger.warn "[MULTIDB] All slaves are blacklisted. Reading from master"
      self.current = @master
    end

    protected

    def create_delegation_method!(method)
      self.instance_eval %Q{
        def #{method}(*args, &block)
          #{'next_reader!' unless self.class.sticky_slave || unsafe?(method)}
          #{target_method(method)}(:#{method}, *args, &block)
        end
      }, __FILE__, __LINE__
    end
    
    def target_method(method)
      unsafe?(method) ? :send_to_master : :send_to_current
    end
    
    def send_to_master(method, *args, &block)
      reconnect_master! if @reconnect
      @master.retrieve_connection.send(method, *args, &block)
    rescue => e
      raise_master_error(e)
    end
    
    def send_to_current(method, *args, &block)
      reconnect_master! if @reconnect && master?
      current.retrieve_connection.send(method, *args, &block)
    rescue NotImplementedError, NoMethodError
      raise
    rescue => e # TODO don't rescue everything
      raise_master_error(e) if master?
      logger.warn "[MULTIDB] Error reading from slave database"
      logger.error %(#{e.message}\n#{e.backtrace.join("\n")})
      @slaves.blacklist!(current)
      next_reader!
      retry
    end
    
    def reconnect_master!
      @master.retrieve_connection.reconnect!
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
      current == @master
    end
        
    def logger
      ActiveRecord::Base.logger
    end

  end
end
