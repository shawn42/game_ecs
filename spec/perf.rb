require_relative '../lib/game_ecs'
require 'pry'

class Player; end
class Foo; end
class Bar; end
class Baz; end
class Tag
  attr_accessor :name
  def initialize(name)
    @name = name
  end
end

class Position
  attr_reader :x, :y
  def initialize(x:,y:)
    @x = x
    @y = y
  end
end

include GameEcs
entity_store = EntityStore.new
enemy_id = entity_store.add_entity Position.new(x:4, y:5)
player_id = entity_store.add_entity Position.new(x:2, y:3), Player.new


entity_store.add_entity Position.new(x:3,y:5), Foo.new, Bar.new, Baz.new
1_000.times do |i|
  entity_store.add_entity Position.new(x:4,y:5), Foo.new, Bar.new, Tag.new("monkey")
  entity_store.add_entity Bar.new
end
1_000.times do |i|
  entity_store.add_entity Foo.new, Bar.new
  entity_store.add_entity Bar.new
end
1_000.times do |i|
  entity_store.add_entity Position.new(x:4,y:5), Bar.new
  entity_store.add_entity Bar.new
end

require 'benchmark'
n = 10#00
records = nil

label = "simple query #{n} times from store with #{entity_store.entity_count} ents:"
# Benchmark.bm(60) do |x|
#   x.report label do
#     n.times do |i|
#       records = entity_store.musts(Position, Tag)
#     end
#   end
# end

# label = "must/maybe query #{n} times from store with #{entity_store.entity_count} ents:"
# Benchmark.bm(60) do |x|
#   x.report label do
#     n.times do |i|
#       records = entity_store.musts(Position, Tag)
#     end
#   end
# end

# label = "complex query creation:"
# q = nil
# Benchmark.bm(60) do |x|
#   x.report label do
#     n.times do |i|
#       q = Q.must(Position).with(x: ->(val){val > 2}).
#       maybe(Foo).
#       maybe(Baz).
#       must(Tag).with(name: "monkey")
#     end
#   end
# end

# label = "complex query #{n} times from store with #{entity_store.entity_count} ents:"
# Benchmark.bm(60) do |x|
#   x.report label do
    
#     complex_query = Q.must(Position).with(x: ->(val){val > 2}).
#     maybe(Foo).
#     maybe(Baz).
#     must(Tag).with(name: "monkey")
#     n.times do |i|
#       # records = entity_store.query(Q.must(Position).maybe(Foo)) # TODO Q.
#       # records = entity_store.query(Q.must(Position).with(x: 3).maybe(Foo)) # TODO Q.
      
#       records = entity_store.query(complex_query) 
      
#       # records = es.query(q.must(Foo).maybe(Bar))
#       # entity_store.remove_entity player_id+n
#       #         if i % 100 == 0
#       #           entity_store.add_component component: Player.new, id: player_id+i
#       #         end
#       #
#       #         if i % 100 == 1
#       #           entity_store.remove_component klass: Player, id: player_id+i-1
#       #         end
#       #
#       #         if i == n-1
#       #           entity_store.remove_entity(player_id)
#       #         end
#       #         entity_store.find(Position, Player)
#     end
#   end
# end

n = 1
Benchmark.bm(10) do |x|
  x.report 'pixel_monster' do
    n.times do |i|
      entity_store = EntityStore.new
      ent_ids = []
      ent_ids << entity_store.add_entity(Position.new(x:3,y:5), Foo.new, Bar.new, Baz.new)
      6_000.times do |i|
        ent_ids << entity_store.add_entity(Position.new(x:4,y:5), Foo.new, Bar.new, Tag.new("monkey"))
        ent_ids << entity_store.add_entity(Bar.new)
      end
      records = entity_store.musts(Position, Tag)
      ent_ids.each do |id|
        entity_store.remove_entity id: id
      end
    end
  end
end