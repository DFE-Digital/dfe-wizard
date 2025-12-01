RSpec.describe DfE::Wizard::Repository::Redis do
  let(:redis) { MockRedis.new }
  let(:repository) { described_class.new(redis:, key: 'wizard:user:123') }

  before do
    allow(redis).to receive(:get).and_return(nil)
    allow(redis).to receive(:set)
    allow(redis).to receive(:setex)
    allow(redis).to receive(:del)
    allow(redis).to receive(:exists?).and_return(false)
    allow(redis).to receive(:ttl).and_return(-2)
    allow(redis).to receive(:expire)
  end

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

  describe '#read' do
    context 'with no data' do
      it 'returns empty hash' do
        allow(redis).to receive(:get).and_return(nil)
        expect(repository.read).to eq({})
      end
    end

    context 'with JSON data' do
      before do
        json = JSON.generate({ name: 'John', email: 'john@example.com' })
        allow(redis).to receive(:get).and_return(json)
      end

      it 'parses and returns data' do
        data = repository.read
        expect(data).to include(name: 'John', email: 'john@example.com')
      end
    end

    context 'with state_key' do
      let(:repository) { described_class.new(redis:, key: 'wizards', state_key: 'user_123') }

      before do
        json = JSON.generate({
                               'user_123' => { 'name' => 'John' },
                               'user_456' => { 'name' => 'Jane' },
                             })
        allow(redis).to receive(:get).and_return(json)
      end

      it 'returns only data for specified state_key' do
        data = repository.read
        expect(data).to include(name: 'John')
      end
    end
  end

  describe '#write' do
    it 'merges data into Redis' do
      json_response = JSON.generate({ 'name' => 'John' })
      allow(redis).to receive(:get).and_return(json_response)

      repository.write({ email: 'john@example.com' })

      expect(redis).to have_received(:set)
    end

    it 'respects expiration' do
      repo_with_ttl = described_class.new(
        redis:,
        key: 'test',
        expiration: 3600,
      )

      repo_with_ttl.write({ name: 'John' })

      expect(redis).to have_received(:setex)
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
    it 'deletes data from Redis' do
      repository.clear
      expect(redis).to have_received(:del).with('wizard:user:123')
    end
  end

  describe '#exists?' do
    it 'checks if key exists' do
      allow(redis).to receive(:exists?).and_return(true)
      expect(repository.exists?).to be true
    end
  end

  describe '#ttl' do
    it 'returns remaining seconds' do
      allow(redis).to receive(:ttl).and_return(3600)
      expect(repository.ttl).to eq(3600)
    end

    it 'returns nil if no expiration' do
      allow(redis).to receive(:ttl).and_return(-1)
      expect(repository.ttl).to be_nil
    end
  end
end
