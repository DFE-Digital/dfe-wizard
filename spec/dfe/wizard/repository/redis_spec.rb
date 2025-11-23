RSpec.describe DfE::Wizard::Repository::Redis do
  let(:redis) { MockRedis.new }
  let(:key) { 'wizard:test' }
  let(:state_key) { nil }
  let(:expiration) { nil }

  subject(:repository) do
    described_class.new(
      redis:,
      key:,
      state_key:,
      expiration:,
    )
  end

  describe '#initialize' do
    it 'requires redis' do
      expect {
        described_class.new(redis: nil, key: 'test')
      }.to raise_error(ArgumentError, 'redis cannot be nil')
    end

    it 'requires key' do
      expect {
        described_class.new(redis: redis, key: nil)
      }.to raise_error(ArgumentError, 'key cannot be nil')
    end
  end

  describe '#read' do
    context 'when key does not exist' do
      it 'returns empty hash' do
        expect(repository.read).to eq({})
      end
    end

    context 'with flat storage' do
      before do
        redis.set(key, JSON.generate({ mentor_id: 1, lp_will_provide: 'yes' }))
      end

      it 'returns symbolized hash' do
        expect(repository.read).to eq({ mentor_id: 1, lp_will_provide: 'yes' })
      end
    end

    context 'with nested storage' do
      let(:state_key) { 'assign_mentor' }

      before do
        redis.set(key, JSON.generate({
                                       'assign_mentor' => { 'mentor_id' => 1 },
                                       'other_wizard' => { 'field' => 'value' },
                                     }))
      end

      it 'returns only data under state_key' do
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
      let(:expiration) { 3600 }

      it 'sets expiration' do
        repository.write({ mentor_id: 1 })
        expect(redis.ttl(key)).to eq(3600)
      end
    end
  end

  describe '#clear' do
    before do
      repository.write({ mentor_id: 1 })
    end

    it 'deletes the key' do
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

  describe '#ttl' do
    context 'with expiration' do
      let(:expiration) { 3600 }

      it 'returns remaining seconds' do
        repository.write({ mentor_id: 1 })
        expect(repository.ttl).to be_within(5).of(3600)
      end
    end

    context 'without expiration' do
      it 'returns nil' do
        repository.write({ mentor_id: 1 })
        expect(repository.ttl).to be_nil
      end
    end
  end

  describe '#refresh_expiration' do
    let(:expiration) { 3600 }

    it 'resets TTL' do
      repository.write({ mentor_id: 1 })
      redis.expire(key, 1800)

      repository.refresh_expiration

      expect(redis.ttl(key)).to eq(3600)
    end
  end
end
