RSpec.describe DfE::Wizard::Repository::Cache do
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:repository) { described_class.new(cache:, key: 'wizard:user:123') }

  describe '#initialize' do
    it 'requires cache and key' do
      expect { described_class.new(cache:) }.to raise_error(ArgumentError)
      expect { described_class.new(key: 'test') }.to raise_error(ArgumentError)
    end

    it 'accepts optional namespace and expires_in' do
      custom_repository = described_class.new(
        cache:,
        key: 'test',
        namespace: 'wizards',
        expires_in: 24.hours,
      )
      expect(custom_repository.namespace).to eq('wizards')
      expect(custom_repository.expires_in).to eq(24.hours.to_i)
    end
  end

  describe '#read' do
    context 'with no data' do
      it 'returns empty hash' do
        expect(repository.read).to eq({})
      end
    end

    context 'with cached data' do
      before do
        cache.write('wizard:user:123', { 'name' => 'John', 'email' => 'john@example.com' })
      end

      it 'returns symbolized data' do
        data = repository.read
        expect(data).to include(name: 'John', email: 'john@example.com')
      end
    end

    context 'with namespace' do
      let(:repository) { described_class.new(cache:, key: 'wizard:123', namespace: 'users') }

      before do
        cache.write('wizard:123', { 'name' => 'John' }, namespace: 'users')
      end

      it 'reads from namespaced key' do
        expect(repository.read).to include(name: 'John')
      end
    end
  end

  describe '#write' do
    it 'merges data into cache' do
      repository.write({ name: 'John' })
      repository.write({ email: 'john@example.com' })

      data = cache.read('wizard:user:123')
      expect(data).to include('name' => 'John', 'email' => 'john@example.com')
    end

    it 'respects expiration' do
      repository_with_ttl = described_class.new(
        cache:,
        key: 'test',
        expires_in: 0.1.second,
      )
      repository_with_ttl.write({ name: 'John' })

      expect(repository_with_ttl.read).to include(name: 'John')
      sleep(0.2)
      expect(repository_with_ttl.read).to eq({})
    end
  end

  describe '#save' do
    it 'replaces entire cached data' do
      cache.write('wizard:user:123', { 'name' => 'John', 'email' => 'john@example.com' })
      repository.save({ 'name' => 'Jane' })

      expect(cache.read('wizard:user:123')).to eq({ 'name' => 'Jane' })
    end
  end

  describe '#execute_operation' do
    class CacheTestStep
      include DfE::Wizard::Step

      attribute :name, :string
      attribute :email, :string

      validates :name, :email, presence: true
    end

    context 'with valid step' do
      let(:step) { CacheTestStep.new(name: 'John', email: 'john@example.com') }

      it 'executes operation in cache context' do
        result = repository.execute_operation(
          operation_class: DfE::Wizard::Operations::Validate,
          step:,
        )

        expect(result[:success]).to be true
      end

      it 'operation can persist to cache' do
        repository.execute_operation(
          operation_class: DfE::Wizard::Operations::Persist,
          step:,
        )

        expect(repository.read).to include(name: 'John')
      end
    end
  end

  describe '#clear' do
    before do
      cache.write('wizard:user:123', { 'name' => 'John' })
    end

    it 'removes data from cache' do
      repository.clear
      expect(cache.read('wizard:user:123')).to be_nil
    end
  end

  describe '#exists?' do
    it 'returns false when data not cached' do
      expect(repository.exists?).to be false
    end

    it 'returns true when data cached' do
      cache.write('wizard:user:123', { 'name' => 'John' })
      expect(repository.exists?).to be true
    end
  end
end
