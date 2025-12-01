RSpec.describe DfE::Wizard::Repository::InMemory do
  let(:repo) { described_class.new }

  describe '#read' do
    context 'with no data' do
      it 'returns empty hash' do
        expect(repo.read).to eq({})
      end
    end

    context 'with saved data' do
      before { repo.save({ name: 'John', email: 'john@example.com' }) }

      it 'returns deep copy of data' do
        data = repo.read
        expect(data).to eq({ name: 'John', email: 'john@example.com' })
      end

      it 'returns copy, not reference' do
        data = repo.read
        data[:name] = 'Modified'
        expect(repo.read[:name]).to eq('John')
      end
    end
  end

  describe '#write' do
    it 'merges data into existing state' do
      repo.write({ name: 'John' })
      repo.write({ email: 'john@example.com' })

      expect(repo.read).to eq({ name: 'John', email: 'john@example.com' })
    end

    it 'deep merges nested data' do
      repo.write({ steps: { name: { first_name: 'John' } } })
      repo.write({ steps: { email: { email_address: 'john@example.com' } } })

      expect(repo.read[:steps]).to include(
        name: { first_name: 'John' },
        email: { email_address: 'john@example.com' },
      )
    end

    it 'overwrites existing keys' do
      repo.write({ name: 'John' })
      repo.write({ name: 'Jane' })

      expect(repo.read[:name]).to eq('Jane')
    end
  end

  describe '#save' do
    it 'replaces entire data' do
      repo.save({ name: 'John', email: 'john@example.com' })
      repo.save({ name: 'Jane' })

      expect(repo.read).to eq({ name: 'Jane' })
    end

    it 'stores deep copy' do
      data = { steps: { name: { first: 'John' } } }
      repo.save(data)
      data[:steps][:name][:first] = 'Modified'

      expect(repo.read[:steps][:name][:first]).to eq('John')
    end
  end

  describe '#execute_operation' do
    class InMemoryTestStep
      include DfE::Wizard::Step

      attribute :name, :string
      attribute :email, :string

      validates :name, :email, presence: true
    end

    context 'with valid step' do
      let(:step) { InMemoryTestStep.new(name: 'John', email: 'john@example.com') }

      it 'executes operation and returns success' do
        result = repo.execute_operation(
          operation_class: DfE::Wizard::Operations::Validate,
          step:,
        )

        expect(result[:success]).to be true
      end

      it 'operation can access repository' do
        repo.execute_operation(
          operation_class: DfE::Wizard::Operations::Persist,
          step:,
        )

        expect(repo.read.symbolize_keys).to eq(name: 'John', email: 'john@example.com')
      end
    end

    context 'with invalid step' do
      let(:step) { InMemoryTestStep.new }

      it 'executes operation and returns failure' do
        result = repo.execute_operation(
          operation_class: DfE::Wizard::Operations::Validate,
          step:,
        )

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end
    end

    context 'operation integration' do
      let(:step) { InMemoryTestStep.new(name: 'Alice') }

      it 'instantiates operation with repository and step' do
        expect_any_instance_of(DfE::Wizard::Operations::Validate).to receive(:execute).and_call_original

        repo.execute_operation(
          operation_class: DfE::Wizard::Operations::Validate,
          step:,
        )
      end

      it 'returns operation result unchanged' do
        result = repo.execute_operation(
          operation_class: DfE::Wizard::Operations::Validate,
          step:,
        )

        expect(result).to be_a(Hash)
        expect(result).to have_key(:success)
      end
    end
  end

  describe '#clear' do
    before { repo.save({ name: 'John', email: 'john@example.com' }) }

    it 'removes all data' do
      repo.clear
      expect(repo.read).to eq({})
    end

    it 'allows new data after clear' do
      repo.clear
      repo.write({ name: 'Jane' })

      expect(repo.read).to eq({ name: 'Jane' })
    end
  end
end
