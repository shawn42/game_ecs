RSpec.describe GameEcs::EntityStore do
  Q = GameEcs::Query

  class Position; end
  class Material; end
  class Color; end

  it 'can be constructed' do
    expect(subject).to be
  end 
  describe '#add_entity' do
    it 'can add empty ent' do
      ent1_id = subject.add_entity
      expect(ent1_id).to be
      ent2_id = subject.add_entity
      expect(ent2_id).not_to eq ent1_id
    end
  end

  describe '#find_by_id' do
    let!(:ent_id) { subject.add_entity(Position.new, Material.new) }

    context 'with all components' do
      context 'with block provide' do
        it 'yields the fully loaded result' do
          res = nil
          subject.find_by_id(ent_id, Position, Material){ |arg| res = arg }
          expect(res.id).to eq ent_id
          expect(res.components.size).to eq 2
          expect(res.components[0]).to be_a Position
          expect(res.components[1]).to be_a Material
        end
      end

      context 'with no block provide' do
        it 'returns fully loaded result' do
          res = subject.find_by_id(ent_id, Position, Material)
          expect(res.id).to eq ent_id
          expect(res.components.size).to eq 2
          expect(res.components[0]).to be_a Position
          expect(res.components[1]).to be_a Material
        end
      end
    end

    context 'missing requested components' do
      it 'returns fully loaded result' do
        res = subject.find_by_id(ent_id, Position, Color)
        expect(res).to be nil
      end
    end
  end

  describe '#clear!' do
    let!(:ent_id) { subject.add_entity(Position.new, Material.new) }

    it 'clears all ents and components' do
      expect(subject.find_by_id(ent_id, Position)).to be
      subject.clear!
      expect(subject.find_by_id(ent_id, Position)).not_to be
    end
  end

  describe '#each_entity' do
    it 'yields each matching ent' do
      ent1 = subject.add_entity(Position.new, Color.new)
      ent2 = subject.add_entity(Position.new)
      ent3 = subject.add_entity(Position.new, Color.new)
      ents = []
      subject.each_entity(Position, Color) do |ent|
        ents << ent
      end
      expect(ents.map(&:id)).to contain_exactly(ent3, ent1)
    end

    it 'can safely remove while iterating' do
      ent1 = subject.add_entity(Position.new, Color.new)
      ent2 = subject.add_entity(Position.new)
      ent3 = subject.add_entity(Position.new, Color.new)
      ents = []
      subject.each_entity(Position, Color) do |ent|
        subject.remove_entity id: ent3 if ent.id == ent1

        ents << ent
      end
      expect(ents.map(&:id)).to contain_exactly(ent3, ent1)
    end

    it 'can safely add while iterating' do
      ent1 = subject.add_entity(Position.new, Color.new)
      ent2 = subject.add_entity(Position.new)
      ent3 = subject.add_entity(Position.new, Color.new)
      ents = []
      subject.each_entity(Position, Color) do |ent|
        subject.add_entity(Position.new, Color.new)
        ents << ent
      end
      expect(ents.map(&:id)).to contain_exactly(ent3, ent1)
    end
  end

  describe "#add_component" do
    context "with unknown entity id" do
      it 'still adds it' do
        subject.add_component(id: 12, component: Position.new )
        ent = subject.find_by_id(12, Position)
        expect(ent).to be
      end
    end

    context "with nil component" do
      it 'errors' do
        ent = subject.add_entity(Position.new, Color.new)
        expect{ subject.add_component(id: ent, component: nil ) }.to raise_exception(/nil/)
      end
    end

  end

  describe '#musts' do
    it 'returns ents that have all the requested components' do
      ent1 = subject.add_entity(Position.new, Color.new)
      ent2 = subject.add_entity(Position.new)
      ent3 = subject.add_entity(Position.new, Color.new)

      results = subject.musts(Position, Color)
      expect(results.size).to eq 2
      expect(results[0].id).to eq ent1
      expect(results[1].id).to eq ent3
    end
  end

  describe '#query' do
    it 'returns the expected entities' do
      ent1 = subject.add_entity(Color.new)
      ent2 = subject.add_entity(Position.new)
      ent3 = subject.add_entity(Position.new, Color.new, Material.new)

      results = subject.query(Q.maybe(Position).must(Color))
      expect(results.size).to eq 2
      expect(results[0].id).to eq ent1
      expect(results[0].components.size).to eq 2
      expect(results[0].components[0]).to be nil

      expect(results[1].id).to eq ent3
      expect(results[1].components.size).to eq 2
      expect(results[1].components[0]).to be_a Position
    end
  end
end