require 'forwardable'
require 'set'

module GameEcs
  class EntityStore
    attr_reader :entity_count, :id_to_comp
    def initialize
      clear!
    end

    def deep_clone
      # NOTE! does not work for Hashes with default procs
      if _iterating?
        raise "AHH! EM is still iterating!!" 
      else
        _apply_updates
        clear_cache!
        em = Marshal.load( Marshal.dump(self) )
        em
      end
    end

    def clear!
      @comp_to_id = {}
      @id_to_comp = {}
      @cache = {}
      @entity_count = 0

      @iterator_count = 0
      @ents_to_add_later = []
      @comps_to_add_later = []
      @comps_to_remove_later = []
      @ents_to_remove_later = []
      clear_cache!
    end

    def clear_cache!
      @cache = {}
    end

    def find_by_id(id, *klasses)
      return nil unless @id_to_comp.key? id
      ent_record = @id_to_comp[id]
      components = ent_record.values_at(*klasses)
      rec = build_record(id, @id_to_comp[id], klasses) unless components.any?(&:nil?)
      if block_given?
        yield rec
      else
        rec
      end
    end

    def musts(*klasses)
      raise "specify at least one component" if klasses.empty?
      q = Q
      klasses.each{|k| q = q.must(k)}
      query(q)
    end
    alias find musts

    def query(q)
      # TODO cache results as q with content based cache
      #   invalidate cache based on queried_comps
      cache_hit = @cache[q]
      return cache_hit if cache_hit

      queried_comps = q.components
      required_comps = q.required_components

      required_comps.each do |k|
        @comp_to_id[k] ||= Set.new
      end

      intersecting_ids = []
      unless required_comps.empty?
        id_collection = @comp_to_id.values_at(*required_comps)
        intersecting_ids = id_collection.sort_by(&:size).inject &:&
      end

      recs = intersecting_ids.
        select{|eid| q.matches?(eid, @id_to_comp[eid]) }.
        map do |eid|
          build_record eid, @id_to_comp[eid], queried_comps
        end
      result = QueryResultSet.new(records: recs, ids: recs.map(&:id))

      @cache[q] = result if q.cacheable?
      result
    end

    def first(*klasses)
      find(*klasses).first
    end

    def each_entity(*klasses, &blk)
      ents = find(*klasses)
      if block_given?
        _iterating do
          ents.each &blk
        end
      end
      ents
    end

    def remove_component(klass:, id:)
      if _iterating?
        _remove_component_later klass: klass, id: id
      else
        _remove_component klass: klass, id: id
      end
    end

    def add_component(component:,id:)
      if _iterating?
        _add_component_later component: component, id: id
      else
        _add_component component: component, id: id
      end
    end

    def remove_entites(ids:)
      if _iterating?
        _remove_entities_later(ids: ids)
      else
        _remove_entites(ids: ids)
      end
    end

    def remove_entity(id:)
      if _iterating?
        _remove_entity_later(id: id)
      else
        _remove_entity(id: id)
      end
    end

    def add_entity(*components)
      id = generate_id
      if _iterating?
        _add_entity_later(id:id, components: components)
      else
        _add_entity(id: id, components: components)
      end
      id
    end

    private
    def _add_entity_later(id:,components:)
      @ents_to_add_later << {components: components, id: id}
    end
    def _remove_entities_later(ids:)
      ids.each do |id|
        @ents_to_remove_later << id
      end
    end
    def _remove_entity_later(id:)
      @ents_to_remove_later << id
    end

    def _remove_component_later(klass:,id:)
      @comps_to_remove_later << {klass: klass, id: id}
    end
    def _add_component_later(component:,id:)
      @comps_to_add_later << {component: component, id: id}
    end

    def _apply_updates
      _remove_entites ids: @ents_to_remove_later
      @ents_to_remove_later.clear

      @comps_to_remove_later.each do |opts|
        _remove_component klass: opts[:klass], id: opts[:id]
      end
      @comps_to_remove_later.clear

      @comps_to_add_later.each do |opts|
        _add_component component: opts[:component], id: opts[:id]
      end
      @comps_to_add_later.clear

      @ents_to_add_later.each do |opts|
        _add_entity id: opts[:id], components: opts[:components]
      end
      @ents_to_add_later.clear
    end

    def _iterating
      @iterator_count += 1
      yield
      @iterator_count -= 1
      _apply_updates unless _iterating?
    end

    def _iterating?
      @iterator_count > 0
    end

    def _add_component(component:,id:)
      raise "Cannot add nil component" if component.nil?

      @comp_to_id[component.class] ||= Set.new
      @comp_to_id[component.class] << id
      @id_to_comp[id] ||= {}
      ent_record = @id_to_comp[id]
      klass = component.class

      raise "Cannot add component twice! #{component} -> #{id}" if ent_record.has_key? klass
      ent_record[klass] = component

      @cache.each do |q, results|
        # TODO make results a smart result set that knows about ids to avoid the linear scan
        # will musts vs maybes help here?
        comp_klasses = q.components
        if comp_klasses.include?(klass)
          if results.has_id?(id)
            results.add_component(id: id, component: component)
          else
            results << build_record(id, ent_record, comp_klasses) if q.matches?(id, ent_record)
          end
        end
      end
      nil
    end

    def _remove_component(klass:, id:)
      @comp_to_id[klass] ||= Set.new
      @comp_to_id[klass].delete id
      @id_to_comp[id] ||= {}
      @id_to_comp[id].delete klass

      @cache.each do |q, results|
        comp_klasses = q.components
        if comp_klasses.include?(klass)
          results.delete(id: id) unless q.matches?(id, @id_to_comp[id])
        end
      end
      nil
    end

    def _remove_entites(ids:)
      return if ids.empty?

      ids.each do |id|
        @id_to_comp.delete(id)
      end

      @comp_to_id.each do |_klass, ents|
        ents.delete_if{|ent_id| ids.include? ent_id}
      end

      @cache.each do |comp_klasses, results|
        results.delete ids: ids
      end
    end

    def _remove_entity(id:)
      comp_map = @id_to_comp[id]
      if @id_to_comp.delete(id)
        ent_comps = comp_map.keys
        ent_comps.each do |klass|
          @comp_to_id[klass].delete id
        end
        @cache.each do |_query, results|
            results.delete id: id
        end
      end
    end

    def _add_entity(id:, components:)
      components.each do |comp|
        _add_component component: comp, id: id
      end
      id
    end

    def generate_id
      @entity_count += 1
      @ent_counter ||= 0
      @ent_counter += 1
    end

    def build_record(*args)
      EntityQueryResult.new(*args)
    end 

    class QueryResultSet
      def initialize(records:, ids:)
        @records = records
        @ids = Set.new(ids)
      end
      def <<(rec)
        @ids << rec.id
        @records << rec
      end
      def has_id?(id)
        @ids.include? id
      end
      def add_component(id:, component:)
        index = @records.index{ |rec| id == rec&.id }
        @records[index].update_component(component) if index >= 0
      end
      def delete(id:nil, ids:nil)
        if id
          @records.delete_at(@records.index{ |rec| id == rec&.id } || @records.size) if @ids.include? id
          @ids.delete id
        else
          unless (@ids & ids).empty?
          # ids.each do |id|
          #   @ids.delete id
          # end
            @ids = @ids - ids
            @records.delete_if{|res| ids.include? res.id}
          end
        end
      end
      def each
        @records.each do |rec|
          yield rec
        end
      end
      extend ::Forwardable
      def_delegators :@records, :first, :any?, :size, :select, :find, :empty?, :first, :map, :[]

    end

    class EntityQueryResult
      attr_reader :id
      def initialize(id, components, queried_components)
        @id = id
        @components = components
        @queried_components = queried_components
      end

      def get(klass)
        @components[klass]
      end

      def update_component(component)
        @components[component.class] = component
        @comp_cache = comp_cache
      end

      def components
        @comp_cache ||= comp_cache
      end

      private
      def comp_cache
        @queried_components.map{|qc| @components[qc]}
      end
    end
  end

  class Condition
    attr_reader :k, :attr_conditions
    def initialize(k)
      @attr_conditions = {}
      @k = k
    end

    def ==(other)
      @k == other.k &&
        @attr_conditions.size == other.attr_conditions.size &&
        @attr_conditions.all?{|ac,v| other.attr_conditions[ac] == v}
    end
    alias eql? ==
    def hash
      @_hash ||= @k.hash ^ @attr_conditions.hash
    end

    def components
      @k
    end

    def attrs_match?(id, comps)
      comp = comps[@k]
      @attr_conditions.all? do |name, cond|
        val = comp.send(name) 
        if cond.respond_to? :call
          cond.call val
        else
          val == cond
        end
      end
    end

    def merge_conditions(attrs)
      @attr_conditions ||= {}
      @attr_conditions.merge! attrs
    end
  end

  class Must < Condition
    def matches?(id, comps)
      comps.keys.include?(@k) && attrs_match?(id, comps)
    end
  end

  class Maybe < Condition
    def matches?(id, comps)
      attrs_match?(id, comps)
    end

  end

  class Query
    attr_reader :components, :musts, :maybes
    def self.none
      Query.new
    end
    def self.must(*args)
      Query.new.must(*args)
    end
    def self.maybe(*args)
      Query.new.maybe(*args)
    end

    def initialize
      @components = []
      @musts = []
    end

    def must(k)
      @last_condition = Must.new(k)
      @musts << @last_condition
      @components << k
      self
    end

    def required_components
      @musts.flat_map(&:components).uniq
    end

    def with(attr_map)
      @last_condition.merge_conditions(attr_map)
      self
    end

    def maybe(k)
      @maybes ||= []
      @last_condition = Maybe.new(k)
      @maybes << @last_condition
      @components << k
      self
    end

    def matches?(eid, comps)
      @musts.all?{|m| m.matches?(eid, comps)} # ignore maybes  ;)
    end

    def ==(other)
      self.musts == other.musts && self.maybes == other.maybes
    end

    def cacheable?
      @cacheable ||= @musts.all?{|m| m.attr_conditions.values.all?{|ac| !ac.respond_to?(:call) } }
    end

    alias eql? ==
    def hash
      @_hash ||= self.musts.hash ^ self.maybes.hash
    end
  end
  Q = Query
end