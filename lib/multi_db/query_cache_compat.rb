module MultiDb
  # Implements the methods expected by the QueryCache module
  module QueryCacheCompat
    def select_all(*a, &b)
      next_reader! unless ConnectionProxy.sticky_slave
      send_to_current(:select_all, *a, &b)
    end
    def columns(*a, &b)
      send_to_current(:columns, *a, &b)
    end
    def insert(*a, &b)
      send_to_master(:insert, *a, &b)
    end
    def update(*a, &b)
      send_to_master(:update, *a, &b)
    end
    def delete(*a, &b)
      send_to_master(:delete, *a, &b)
    end
  end
end