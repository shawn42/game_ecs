# TODO docs here
class TimerSystem
  def update(store, inputs)
    current_time_ms = inputs[:total_time]
    store.each_entity Timer do |rec|
      timer = rec.get(Timer)
      ent_id = rec.id

      if timer.expires_at
        if timer.expires_at < current_time_ms
          if timer.event
            event_comp = timer.event.is_a?(Class) ? timer.event.new : timer.event
            store.add_component component: event_comp, id: ent_id
          end
          if timer.repeat
            timer.expires_at = current_time_ms + timer.total
          else
            store.remove_component(klass: timer.class, id: ent_id)
          end
        end
      else
        timer.expires_at = current_time_ms + timer.total
      end
    end
  end
end
class Timer
  attr_accessor :ttl, :repeat, :total, :event, :name, :expires_at
  def initialize(name, ttl, repeat, event = nil)
    @name = name
    @total = ttl
    @ttl = ttl
    @repeat = repeat
    @event = event
  end
end

class SoundSystem
  def update(store, inputs)
    store.each_entity SoundEffectEvent do |rec|
      ent_id = rec.id
      effect = rec.get(SoundEffectEvent)
      store.remove_component klass: effect.class, id: ent_id
      Gosu::Sample.new(effect.sound_to_play).play
    end
  end
end
SoundEffectEvent = Struct.new :sound_to_play
