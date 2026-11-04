RSpec.describe DfE::Wizard::Repository::Redis do
  let(:redis) { MockRedis.new }
  let(:repository) { described_class.new(redis:, key: 'wizard:user:123') }

  describe '#initialize' do
    it 'requires redis and key' do
      expect { described_class.new(redis:) }.to raise_error(ArgumentError)
      expect { described_class.new(key: 'test') }.to raise_error(ArgumentError)
    end

    it 'accepts optional state_key and expiration' do
      custom_repository = described_class.new(
        redis:,
        key: 'test',
        state_key: 'wizard_1',
        expiration: 86400,
      )
      expect(custom_repository.state_key).to eq('wizard_1')
      expect(custom_repository.expiration).to eq(86400)
    end
  end

  describe 'encryption behavior' do
    include_examples 'repository encryption'
    let(:unencrypted_repository) do
      build_repository(encrypted: false, key: 'wizard:user:1000', encryptor: nil)
    end
    let(:encrypted_repository) do
      build_repository(encrypted: true, key: 'wizard:user:1001', encryptor:)
    end

    def build_repository(key: 'wizard', encrypted: false, encryptor: nil)
      described_class.new(redis:, key:, encrypted:, encryptor:)
    end
  end

  describe '#read' do
    context 'with no data' do
      it 'returns empty hash' do
        expect(repository.read).to eq({})
      end
    end

    context 'with JSON data' do
      before do
        redis.set('wizard:user:123', JSON.generate({ name: 'John', email: 'john@example.com' }))
      end

      it 'parses and returns data' do
        data = repository.read
        expect(data).to include(name: 'John', email: 'john@example.com')
      end
    end

    context 'with state_key' do
      let(:repository) { described_class.new(redis:, key: 'wizards', state_key: 'user_123') }

      before do
        redis.set('wizards', JSON.generate({
                                             'user_123' => { 'name' => 'John' },
                                             'user_456' => { 'name' => 'Jane' },
                                           }))
      end

      it 'returns only data for specified state_key' do
        data = repository.read
        expect(data).to include(name: 'John')
      end
    end
  end

  describe '#write' do
    it 'merges data into Redis' do
      repository.write({ name: 'John' })
      repository.write({ email: 'john@example.com' })

      data = repository.read
      expect(data).to include(name: 'John', email: 'john@example.com')
    end

    it 'respects expiration' do
      repo_with_ttl = described_class.new(
        redis:,
        key: 'test',
        expiration: 3600,
      )

      repo_with_ttl.write({ name: 'John' })

      # Verify data was written
      expect(redis.exists?('test')).to be true
    end

    context 'when a key is written twice' do
      it 'returns the new value' do
        repository.write({ first_name: 'a' })
        repository.write({ first_name: 'b' })

        expect(repository.read).to eq(first_name: 'b')
      end

      it 'stores the key once' do
        repository.write({ first_name: 'a' })
        repository.write({ first_name: 'b' })

        expect(JSON.parse(redis.get('wizard:user:123'))).to eq('first_name' => 'b')
      end

      it 'keeps the other keys' do
        repository.write({ first_name: 'a', email: 'a@example.com' })
        repository.write({ first_name: 'b' })

        expect(repository.read).to eq(first_name: 'b', email: 'a@example.com')
      end

      it 'replaces a value with nil' do
        repository.write({ first_name: 'a' })
        repository.write({ first_name: nil })

        expect(repository.read).to eq(first_name: nil)
      end

      it 'replaces a nested hash value' do
        repository.write({ address: { line1: 'old' } })
        repository.write({ address: { line1: 'new' } })

        expect(repository.read).to eq(address: { line1: 'new' })
      end

      it 'replaces a value written with a symbol key by one written with a string key' do
        repository.write({ first_name: 'a' })
        repository.write({ 'first_name' => 'b' })

        expect(repository.read).to eq(first_name: 'b')
        expect(JSON.parse(redis.get('wizard:user:123'))).to eq('first_name' => 'b')
      end
    end

    context 'when a key is written twice with a state_key' do
      let(:repository) { described_class.new(redis:, key: 'wizards', state_key: 'user_123') }

      before do
        redis.set('wizards', JSON.generate('user_456' => { 'first_name' => 'Jane' }))
      end

      it 'returns the new value and keeps the other states' do
        repository.write({ first_name: 'a' })
        repository.write({ first_name: 'b' })

        expect(repository.read).to eq(first_name: 'b')
        expect(JSON.parse(redis.get('wizards'))).to eq(
          'user_123' => { 'first_name' => 'b' },
          'user_456' => { 'first_name' => 'Jane' },
        )
      end
    end

    context 'when a key is written twice with encryption' do
      let(:encryptor) do
        key = ActiveSupport::KeyGenerator.new('test-secret-encryption-key-123')
                                         .generate_key('fixed-salt-for-reproducible-tests', 32)
        ActiveSupport::MessageEncryptor.new(key)
      end

      it 'returns the new value' do
        encrypted_repository = described_class.new(redis:, key: 'wizard:user:123', encrypted: true, encryptor:)
        encrypted_repository.write({ first_name: 'a' })
        encrypted_repository.write({ first_name: 'b' })

        expect(encrypted_repository.read).to eq(first_name: 'b')
        expect(JSON.parse(redis.get('wizard:user:123')).keys).to eq(['first_name'])
      end

      it 'returns the new value with a state_key' do
        encrypted_repository = described_class.new(
          redis:, key: 'wizards', state_key: 'user_123', encrypted: true, encryptor:,
        )
        encrypted_repository.write({ first_name: 'a' })
        encrypted_repository.write({ first_name: 'b' })

        expect(encrypted_repository.read).to eq(first_name: 'b')
      end
    end

    it 'leaves save as a full replacement after a write' do
      repository.write({ first_name: 'a', email: 'a@example.com' })
      repository.save({ email: 'b@example.com' })

      expect(repository.read).to eq(email: 'b@example.com')
    end
  end

  describe '#execute_operation' do
    class RedisTestStep
      include DfE::Wizard::Step

      attribute :name, :string
      attribute :email, :string

      validates :name, :email, presence: true
    end

    let(:step) { RedisTestStep.new(name: 'John', email: 'john@example.com') }

    it 'executes operation in Redis context' do
      result = repository.execute_operation(
        operation_class: DfE::Wizard::Operations::Validate,
        step:,
      )

      expect(result[:success]).to be true
    end
  end

  describe '#clear' do
    before do
      redis.set('wizard:user:123', JSON.generate({ name: 'John' }))
    end

    it 'deletes data from Redis' do
      repository.clear
      expect(redis.get('wizard:user:123')).to be_nil
    end
  end

  describe '#exists?' do
    it 'returns false when key does not exist' do
      expect(repository.exists?).to be false
    end

    it 'returns true when key exists' do
      redis.set('wizard:user:123', JSON.generate({ name: 'John' }))
      expect(repository.exists?).to be true
    end
  end

  describe '#ttl' do
    it 'returns nil if no expiration' do
      redis.set('wizard:user:123', JSON.generate({ name: 'John' }))
      expect(repository.ttl).to be_nil
    end
  end
end
