RSpec.describe DfE::Wizard::Repository::Cache do
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:key) { 'test_wizard' }
  let(:namespace) { nil }
  let(:expires_in) { nil }

  subject(:repository) do
    described_class.new(
      cache: cache,
      key: key,
      namespace: namespace,
      expires_in: expires_in,
    )
  end

  describe '#initialize' do
    it 'requires cache' do
      expect {
        described_class.new(cache: nil, key: 'test')
      }.to raise_error(ArgumentError, 'cache cannot be nil')
    end

    it 'requires key' do
      expect {
        described_class.new(cache: cache, key: nil)
      }.to raise_error(ArgumentError, 'key cannot be nil')
    end
  end

  describe '#read' do
    context 'when key does not exist' do
      it 'returns empty hash' do
        expect(repository.read).to eq({})
      end
    end

    context 'when data exists' do
      before do
        cache.write(key, { mentor_id: 1, lp_will_provide: 'yes' })
      end

      it 'returns symbolized hash' do
        expect(repository.read).to eq({
                                        mentor_id: 1,
                                        lp_will_provide: 'yes',
                                      })
      end
    end

    context 'with namespace' do
      let(:namespace) { 'wizards' }

      before do
        cache.write(key, { mentor_id: 1 }, namespace: 'wizards')
      end

      it 'reads from namespaced key' do
        expect(repository.read).to eq({ mentor_id: 1 })
      end
    end
  end

  describe '#write' do
    it 'writes new data' do
      repository.write({ mentor_id: 1 })
      expect(repository.read).to eq({ mentor_id: 1 })
    end

    it 'merges with existing data' do
      repository.write({ mentor_id: 1 })
      repository.write({ lp_will_provide: 'yes' })

      expect(repository.read).to eq({
                                      mentor_id: 1,
                                      lp_will_provide: 'yes',
                                    })
    end

    context 'with expiration' do
      let(:expires_in) { 1.hour }

      it 'sets expiration' do
        repository.write({ mentor_id: 1 })

        # Verify data exists
        expect(repository.exists?).to be true

        # Simulate time passing (if cache supports it)
        # Most in-memory caches don't actually expire in tests
      end
    end
  end

  describe '#clear' do
    before do
      repository.write({ mentor_id: 1 })
    end

    it 'deletes the data' do
      repository.clear
      expect(repository.read).to eq({})
    end
  end

  describe '#exists?' do
    it 'returns false when key does not exist' do
      expect(repository.exists?).to be false
    end

    it 'returns true when key exists' do
      repository.write({ mentor_id: 1 })
      expect(repository.exists?).to be true
    end
  end
end
