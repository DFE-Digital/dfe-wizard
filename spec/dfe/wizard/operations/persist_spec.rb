RSpec.describe DfE::Wizard::Operations::Persist do
  let(:repository) { DfE::Wizard::Repository::InMemory.new }

  class PersonalDetailsStep
    include DfE::Wizard::Step

    attribute :first_name
    attribute :last_name
    attribute :date_of_birth

    validates :first_name, presence: true
    validates :last_name, presence: true
    validates :date_of_birth, presence: true

    def serializable_data
      {
        first_name:,
        last_name:,
        date_of_birth:,
      }
    end
  end

  describe '#execute' do
    context 'with valid step data' do
      let(:step) do
        PersonalDetailsStep.new(
          first_name: 'John',
          last_name: 'Doe',
          date_of_birth: Date.new(1990, 1, 1),
        )
      end

      let(:persister) { described_class.new(repository:, step:) }

      it 'returns success: true' do
        result = persister.execute

        expect(result[:success]).to be true
      end

      it 'writes step data to repository' do
        persister.execute

        expect(repository.read).to include(
          first_name: 'John',
          last_name: 'Doe',
        )
      end

      it 'preserves date_of_birth' do
        persister.execute

        expect(repository.read[:date_of_birth]).to eq(Date.new(1990, 1, 1))
      end

      it 'only has success key in result' do
        result = persister.execute

        expect(result.keys).to eq([:success])
      end
    end

    context 'with empty step data' do
      let(:step) do
        PersonalDetailsStep.new(
          first_name: '',
          last_name: '',
          date_of_birth: nil,
        )
      end

      let(:persister) { described_class.new(repository:, step:) }

      it 'still persists (even if invalid)' do
        result = persister.execute

        expect(result[:success]).to be true
      end

      it 'writes empty data to repository' do
        persister.execute

        expect(repository.read).to include(
          first_name: '',
          last_name: '',
        )
      end

      it 'writes nil date_of_birth' do
        persister.execute

        expect(repository.read[:date_of_birth]).to be_nil
      end
    end

    context 'with partial data' do
      let(:step) do
        PersonalDetailsStep.new(
          first_name: 'Jane',
          last_name: 'Smith',
          date_of_birth: nil,
        )
      end

      let(:persister) { described_class.new(repository:, step:) }

      it 'persists what is provided' do
        persister.execute

        expect(repository.read).to include(
          first_name: 'Jane',
          last_name: 'Smith',
        )
      end

      it 'persists nil values' do
        persister.execute

        expect(repository.read).to have_key(:date_of_birth)
        expect(repository.read[:date_of_birth]).to be_nil
      end
    end
  end

  describe '#rollback' do
    let(:step) do
      PersonalDetailsStep.new(
        first_name: 'John',
        last_name: 'Doe',
        date_of_birth: Date.new(1990, 1, 1),
      )
    end

    let(:persister) { described_class.new(repository:, step:) }

    it 'does nothing (no-op)' do
      persister.execute
      data_before_rollback = repository.read

      persister.rollback

      expect(repository.read).to eq(data_before_rollback)
    end

    it 'data remains after rollback' do
      persister.execute
      persister.rollback

      expect(repository.read).to include(first_name: 'John')
    end
  end

  describe 'integration with repository' do
    let(:step) do
      PersonalDetailsStep.new(
        first_name: 'Alice',
        last_name: 'Johnson',
        date_of_birth: Date.new(1985, 5, 15),
      )
    end

    it 'uses repository passed in constructor' do
      persister = described_class.new(repository:, step:)
      result = persister.execute

      expect(result[:success]).to be true
    end

    it 'calls write on repository' do
      persister = described_class.new(repository:, step:)
      persister.execute

      expect(repository.read).not_to be_empty
    end

    it 'works with repository.execute_operation' do
      result = repository.execute_operation(described_class, step)

      expect(result[:success]).to be true
      expect(repository.read).to include(first_name: 'Alice')
    end
  end

  describe 'data preservation' do
    let(:step) do
      PersonalDetailsStep.new(
        first_name: 'Bob',
        last_name: 'Wilson',
        date_of_birth: Date.new(1995, 12, 25),
      )
    end

    it 'serializes step data correctly' do
      persister = described_class.new(repository:, step:)
      persister.execute

      expect(repository.read).to eq(step.serializable_data)
    end

    it 'preserves data types' do
      persister = described_class.new(repository:, step:)
      persister.execute

      expect(repository.read[:date_of_birth]).to be_a(Date)
      expect(repository.read[:first_name]).to be_a(String)
    end
  end

  describe 'with existing repository data' do
    let(:step) do
      PersonalDetailsStep.new(
        first_name: 'Eve',
        last_name: 'Davis',
        date_of_birth: Date.new(2000, 3, 10),
      )
    end

    it 'merges with existing data' do
      repository.write(previous_field: 'previous_value')
      persister = described_class.new(repository:, step:)
      persister.execute

      expect(repository.read).to include(
        previous_field: 'previous_value',
        first_name: 'Eve',
      )
    end

    it 'overwrites conflicting keys' do
      repository.write(first_name: 'Old', other: 'data')
      persister = described_class.new(repository:, step:)
      persister.execute

      expect(repository.read[:first_name]).to eq('Eve')
      expect(repository.read[:other]).to eq('data')
    end
  end

  describe 'multiple persist operations' do
    let(:step1) do
      PersonalDetailsStep.new(
        first_name: 'John',
        last_name: 'Doe',
        date_of_birth: Date.new(1990, 1, 1),
      )
    end

    let(:step2) do
      PersonalDetailsStep.new(
        first_name: 'Jane',
        last_name: 'Smith',
        date_of_birth: Date.new(1985, 6, 15),
      )
    end

    it 'second persist overwrites first' do
      persister1 = described_class.new(repository:, step: step1)
      persister1.execute

      persister2 = described_class.new(repository:, step: step2)
      persister2.execute

      expect(repository.read[:first_name]).to eq('Jane')
      expect(repository.read[:last_name]).to eq('Smith')
    end
  end
end
