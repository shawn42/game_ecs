module GameEcs
  class SimpleSystem
    def self.from_query(query, &block)
      new(query, &block)
    end
    
    def initialize(query=Query.none, &block)
      @query = query
      @system_block = block
    end

    def update(entity_store, *args)
      before_update(entity_store, *args)
      entity_store.query.each do |ent|
        each(ent, *args)
      end
      after_update(entity_store, *args)
    end

    def before_update(entity_store, *args)
    end
    def after_update(entity_store, *args)
    end
    def update_each(entity_store, ent, *args)
      # handle a single update of an ent
      @system_block.call(entity_store, ent, *args)
    end
  end

end

if $0 == __FILE__
include GameEcs
  MovementSystem = SimpleSystem.from_query( Q.musts(Position, Velocity) ) do |store, ent, dt, input|
    pos,vel = ent.components
    pos.x += vel.x * dt
    pos.y += vel.y * dt
  end

  # long hand via subclassing, allows for before/after overrides
  class MovementSystem < SimpleSystem
    def after_update(store, *args)
      log "MovementSystem finished: #{Time.now}"
    end
    def update_each(store, ent, dt, input)
      Q.each_entity(Position, Velocity) do
        pos,vel = ent.components
        pos.x += vel.x * dt
        pos.y += vel.y * dt
      end
    end
  end
end