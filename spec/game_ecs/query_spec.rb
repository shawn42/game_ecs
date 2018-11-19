RSpec.describe GameEcs::Query do
  describe '.none' do
    let(:store) { GameEcs::EntityStore.new }
    it '.none' do
      ent1 = store.add_entity(Position.new, Color.new)
      ent2 = store.add_entity(Position.new)
      ent3 = store.add_entity(Position.new, Color.new)
      ents = store.query(Q.none)
      expect(ents).to be_empty
    end
  end

  describe 'hashing' do
    context 'simple query' do
      it 'returns the correct value from the hash using the query as a key' do
        q = Q.must(Position)
        cache = {}
        cache[q] = :some_val
        expect(cache[q]).to eq :some_val
        
        expect(cache[Q.must(Position)]).to eq :some_val
      end
    end

    context 'complex query' do
      it 'returns the correct value from the hash using the query as a key' do
        q = Q.must(Position).maybe(Color)
        cache = {}
        cache[q] = :some_val
        expect(cache[q]).to eq :some_val
        expect(cache[Q.must(Position).maybe(Color)]).to eq :some_val
      end
    end

    context 'complex query' do
      it 'returns the correct value from the hash using the query as a key' do
        q = Q.must(Position).maybe(Color).with(name: "monkey")
        cache = {}
        cache[q] = :some_val
        expect(cache[q]).to eq :some_val
        expect(cache[Q.must(Position).maybe(Color).with(name: "monkey")]).to eq :some_val
      end
    end

    context 'complex query with lambda' do
      it 'does not cache the query if a lambda is used' do
        q = Q.must(Position).maybe(Color).with(x: ->(val){ val > 2 })
        cache = {}
        cache[q] = :some_val
        expect(cache[q]).to eq :some_val
        expect(cache[Q.must(Position).maybe(Color).with(x: ->(val){ val > 2 })]).not_to eq :some_val
      end
    end
      
  end
end