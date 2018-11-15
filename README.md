# GameEcs

An easy to use Entity Component System library for use in game development. Learn more about ECS here: 
* [Evolve Your Heirachy](http://cowboyprogramming.com/2007/01/05/evolve-your-heirachy/)
* [Wikipedia](https://en.wikipedia.org/wiki/Entity%E2%80%93component%E2%80%93system)

Getting Started

* [Installation](#installation)
* [Usage](#usage)
  * [Components](#components)
  * [Creating Entities](#creating-entities)
  * [Add/Remove Components](#adding-and-removing-components)
  * [Finding Entities](#finding-entities)
  * [Updating Components](#updating-components)
  * [Advanced Querying](#advanced-querying)
  * [Big Picture](#big-picture)
* [Notes](#notes)

### Adding and Removing Components

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'game_ecs'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install game_ecs

## Usage

### Components

Components in GameEcs are ordinary Ruby classes. In most cases, they should be struct-like classes with `attr_accessor` properties only. Adding default values in the constructor is as advanced as these objects should get.

```ruby
# Example components
class Position
  attr_accessor :x, :y
  def initialize(x:0,y:0)
    @x = x
    @y = y
  end
end

class Tag
  attr_accessor :name
  def initialize(name:)
    @name = name
  end
end
```

### Creating Entities

An Entity is simply a collection of Components joined together by an id. To create one, simply call the `add_entity` method with a list of the Components you want the Entity to initially have:

```ruby
# Create and save your store in your higher level Game / State class
store = GameEcs::EntityStore.new 

# Creating an entity returns its id.
# In most cases, you will not need to keep this id around.
ent_id = store.add_entity(Position.new(x:1,y:3), Tag.new(name:"Player"))
```

I recommend creating an `EntityFactory` or `Prefab` class to store factory methods that know how to build each kind of entity:

```ruby
class Prefab
  def self.player_at(store:, x:,y:)
    store.add_entity(Position.new(x:x,y:y), Tag.new(name:"Player"))
  end

  def self.tank(*args)
    # ...
  end

  # etc
end
```

### Adding and Removing Components

The great thing about ECS is the ability to add/remove components at runtime. Here's how to do it:

```ruby
# add a Color component
store.add_component(id: ent_id, component: Color.new(red: 255, green: 255, blue: 0))

# we remove by class
store.remove_component(id: ent_id, klass: Color)

# remove an entire entity
store.remove_entity(id: ent_id)

# remove many entities
store.remove_entities(ids: list_of_ids)
```

### Finding Entities

There are two main ways of finding the entities you want. You can ask for them directly by id or you can search for them by Components.

#### By Id
Finding by id is nice if you are looking for a single entity. You merely specify the id and the components you want available for modification. If the id does not exist or the entity does not have one of the specified components, `nil` is returned.

```ruby
ent = store.find_by_id(ent_id, Position, Color)
id = ent.id
pos, color = ent.components
```

#### Querying by Components

GameEcs has a `Query` class that can be used for more advanced queries, but the most common case is that you want all enitities that have all the components you're interested in. `musts` is short had for building these types of queries:

```ruby
ents_that_need_move = store.musts(Position, Velocity)
ents_that_need_move.each do |ent|
  pos,vel = ent.components
  # modify pos based on vel
end
```

This pattern of find the ents and loop over them is so common there is a helper that does just that called `each_entity`:

```ruby
store.each_entity(Position, Velocity) do |ent|
  pos,vel = ent.components
  # modify pos based on vel
end
```

### Updating Components

Once you've got hold of an "entity" from the store. You can access the components you queried for via the `components` method on the entity. Once you have it, you can directly modify its values.

```ruby
store.each_entity(Position, Velocity) do |ent|
  pos,vel = ent.components
  pos.x += vel.x * time_scale
  pos.y += vel.y * time_scale
end
```

### Advanced Querying

`each_entity` and `musts` are really shorthand for creating `GameEcs::Query` objects and passing it to the `query` method. Let's look at the longhand version; the following two lines are synonymous:

```ruby
ents = store.query(Query.must(Position).must(Color))
ents = store.musts(Position, Color)
```

By using the `Query` directly, we can add in `maybe` cases. A Maybe will still match if the entity does not have the desired component, but will return nil for that component.


```ruby
store.query(Query.must(Position).maybe(Color)).each do |ent|
  # color may be nil
  pos,color = ent.components
end
```

#### Experimental!
We can also query based on components' values using `with`:

```ruby
# Only entities with a Position component with x val == 12 will be returned
store.query(Query.must(Position).with(x: 12).must(Color)).each do |ent|
  pos,color = ent.components
end
```

We can also use lambdas to determine if a value matches:
```ruby
# Only entities with a Position less than 12 will be returned
store.query(Query.must(Position).with(x: ->(x){ x < 12 }).must(Color)).each do |ent|
  pos,color = ent.components
end
```

*_!! DANGER !!_*

Currently the caching mechanism in GameEcs does not know if the value of a component has changed since it was cached. Only use this for component values that do not change often, or clear your cache to get the results to update. The rough plan here is to eventually change components to be more of a DSL and have them notify the store on value changes of interest (If any queries care about the change)

### Big Picture

`EntityStore` is meant to be constructed and passed into a list of processing systems. This gem is entirely agnostic to how you implement your Game and Systems. A quick example _could_ look like:

```ruby
class Game
  def intialize
    @store = GameEcs::EntityStore.new
    @render_system = RenderSystem.new(@store)
    @systems = [
      MovementSystem.new(@store),
      # .. other systems
      @render_system
    ]
  end

  def update(time_delta, inputs)
    @systems.each{|sys| sys.update(time_delta, inputs) }
  end

  def draw
    @render_system.render
  end
end

class MovementSystem
  def initialize(store)
    @store = store
  end

  def update(dt, inputs)
    @store.each_entity(Position, Velocity) do |ent|
      pos,vel = ent.components
      pos.x += vel.x * dt
      pos.y += vel.y * dt
    end
  end
end


```
For a more fully fleshed out game using ECS in this way, checkout [Pixel Monster](https://github.com/shawn42/pixel_monster)


### Notes

* entities can only have one instance of each component type
* adding/removing entities and components is delayed until all iterating code has finished (calls to `each_entity`).
* all queries are cached by default calling `clear_cache!` will reset the cache
* to dump all entities and components from the store, use `clear!`


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/shawn42/game_ecs.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
