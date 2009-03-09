module MultiDb
  module ThreadLocalAccessors
    # Creates thread-local accessors for the given attribute name.
    #
    # The first invokation of the setter will make this value the default
    # for any subsequent threads.
    def tlattr_accessor(name)
      ivar = "@_tlattr_#{name}"
      class_eval %Q{
        def #{name}
          if #{ivar}
            #{ivar}[Thread.current.object_id]
          else
            nil
          end
        end

        def #{name}=(val)
          if #{ivar}
            unless #{ivar}.has_key?(Thread.current.object_id)
              ObjectSpace.define_finalizer(Thread.current, lambda {|id| #{ivar}.delete(id) })
            end
            #{ivar}[Thread.current.object_id] = val
          else
            #{ivar} = Hash.new {|h, k| h[k] = val}
            val
          end
        end
      }, __FILE__, __LINE__
    end
  end
end
