$: << '../lib'
$: << '../contrib'
require_relative '../lib/game_ecs'
require_relative '../contrib/sample_systems_components'

require 'gosu'
include Gosu
Q = GameEcs::Query

class CoinGetterGame < Window
  def initialize
    super(800,600)
    @entity_store = GameEcs::EntityStore.new
    @render_system = RenderSystem.new
    @downs = []

    @systems = [
      ControlSystem.new,
      MotionSystem.new,
      TimerSystem.new,
      CoinSystem.new,
      SoundSystem.new,
      @render_system
    ]

    Prefab.player(@entity_store, 400, 300)
    10.times do
      Prefab.coin(@entity_store, rand(50..750), rand(50..550))
    end
    Prefab.coin_gen_timer(@entity_store)
  end

  def button_down(id)
    close if id == KbEscape
    @downs << id
  end
  def button_up(id)
    @downs.delete id
  end

  def update
    @systems.each do |sys|
      sys.update(@entity_store, {dt: relative_delta, down_ids: @downs, total_time: Gosu::milliseconds})
    end
  end

  def draw
    @render_system.draw(@entity_store, self)
  end


  private

  MAX_UPDATE_SIZE_IN_MILLIS = 500
  def relative_delta
    total_millis = Gosu::milliseconds.to_f
    @last_millis ||= total_millis
    delta = total_millis
    delta -= @last_millis if total_millis > @last_millis
    @last_millis = total_millis
    delta = MAX_UPDATE_SIZE_IN_MILLIS if delta > MAX_UPDATE_SIZE_IN_MILLIS
    delta
  end
end

class Prefab
  def self.coin(store, x, y)
    store.add_entity(Position.new(x,y,1), Velocity.new(0.5-rand,0.5-rand), Color.new(:green), Size.new(10), Tag.new("coin") )
  end

  def self.player(store, x, y)
    store.add_entity(Position.new(400,40,3), Tag.new("p1"), Score.new(0))
    store.add_entity(Position.new(x,y,2), Velocity.new(0,0), Color.new(:red), Tag.new("p1"), Input.new, Size.new(20))
  end

  def self.coin_gen_timer(store)
    store.add_entity(Timer.new(:coin_gen, 2000, true, GenerateNewCoinEvent))
  end
end


# Systems
class ControlSystem
  def update(store, inputs)
    downs = inputs[:down_ids]
    player_one = store.query(Q.must(Input).must(Tag).with(name: "p1")).first.get(Input)
    player_one.left = downs.include?(KbLeft) || downs.include?(GpLeft)
    player_one.right = downs.include?(KbRight) || downs.include?(GpRight)
    player_one.up = downs.include?(KbUp) || downs.include?(GpUp)
    player_one.down = downs.include?(KbDown) || downs.include?(GpDown)
  end
end
class MotionSystem
  MAX_VELOCITY = 2
  ACCEL = 0.03
  FRICTION = 0.96
  def update(store, inputs)
    time_scale = inputs[:dt] * 0.01
    store.each_entity(Input, Velocity) do |ent|
      input, vel = ent.components
      vel.dx += ACCEL*time_scale if input.right
      vel.dx -= ACCEL*time_scale if input.left
      vel.dy += ACCEL*time_scale if input.down
      vel.dy -= ACCEL*time_scale if input.up

      vel.dx *= FRICTION
      vel.dy *= FRICTION

      mag = vec_mag(vel.dx, vel.dy) 
      if mag > MAX_VELOCITY 
        vel.dx, vel.dy = vec_clip_to_mag(vel.dx, vel.dy, MAX_VELOCITY)
      end
    end

    store.each_entity(Position, Velocity) do |ent|
      pos,vel = ent.components
      pos.x += vel.dx*time_scale
      pos.y += vel.dy*time_scale
      pos.x %= 800
      pos.y %= 600
    end
  end
  def vec_mag(x,y)
    Math.sqrt(x*x + y*y)
  end
  def vec_clip_to_mag(x,y,max_mag)
    mag = vec_mag(x,y)
    [x.to_f/mag*max_mag, y.to_f/mag*max_mag]
  end
end

class RenderSystem
  def initialize
    @colors = {
      red: Gosu::Color::RED,
      green: Gosu::Color::GREEN
    }
    @font = Gosu::Font.new(40)
  end
  def update(store,inputs); end
  def draw(store, target)
    store.each_entity(Position, Score) do |ent|
      pos, score = ent.components
      @font.draw("#{score.points}", pos.x, pos.y, pos.z, 1.0, 1.0, Gosu::Color::WHITE)
    end
    store.each_entity(Position, Color, Size) do |ent|
      pos, col, size = ent.components
      w = size.width
      c1 = c2 = c3 = c4 = @colors[col.name]
      x1 = pos.x
      x2 = pos.x + w
      x3 = x2
      x4 = x1

      y1 = pos.y
      y2 = y1
      y3 = pos.y + w
      y4 = y3

      target.draw_quad(x1, y1, c1, x2, y2, c2, x3, y3, c3, x4, y4, c4, pos.z)
    end
  end
end

class CoinSystem
  def update(store, inputs)
    p1_score = store.query(Q.must(Score).must(Tag).with(name: "p1")).first
    p1_score, _ = p1_score.components
    p1 = store.query(Q.must(Position).must(Size).must(Tag).with(name: "p1")).first
    p1_pos, p1_size, _ = p1.components

    store.query(Q.must(Position).must(Size).must(Tag).with(name:"coin")).each do |coin|
      coin_pos, coin_size, _ = coin.components
      if (coin_pos.x >= p1_pos.x &&
        coin_pos.x <= p1_pos.x + p1_size.width) ||
        (coin_pos.x + coin_size.width >= p1_pos.x &&
        coin_pos.x + coin_size.width <= p1_pos.x + p1_size.width)

        if (coin_pos.y >= p1_pos.y &&
          coin_pos.y <= p1_pos.y + p1_size.width) ||
          (coin_pos.y + coin_size.width >= p1_pos.y &&
          coin_pos.y + coin_size.width <= p1_pos.y + p1_size.width)

          store.remove_entity(id: coin.id)
          p1_score.points += 1
          store.add_entity SoundEffectEvent.new('coin.wav')
        end
      end
    end
    store.each_entity(GenerateNewCoinEvent) do |ent|
      Prefab.coin(store, rand(50..750), rand(50..550))
      store.remove_component(klass: GenerateNewCoinEvent, id: ent.id)
    end
  end
end

# Components
class Input
  attr_accessor :left, :right, :up, :down
end
GenerateNewCoinEvent = Class.new
Tag = Struct.new :name
Position = Struct.new :x, :y, :z
Size = Struct.new :width
Velocity = Struct.new :dx, :dy
Color = Struct.new :name
Score = Struct.new :points

if $0 == __FILE__
  game = CoinGetterGame.new
  game.show
end