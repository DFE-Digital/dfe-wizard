RSpec.describe DfE::Wizard::Operations::Validate do
  subject(:validator) { described_class.new(repository:, step:) }

  class PersonalDetailStep
    include DfE::Wizard::Step

    attribute :first_name
    attribute :last_name
    attribute :date_of_birth

    validates :first_name, presence: true, length: { maximum: 100 }
    validates :last_name, presence: true, length: { maximum: 100 }
    validates :date_of_birth, presence: true

    def serializable_data
      {
        first_name: first_name,
        last_name: last_name,
        date_of_birth: date_of_birth,
      }
    end
  end

  let(:repository) { DfE::Wizard::Repository::InMemory.new }

  describe '#execute' do
    context 'when step is valid' do
      let(:step) do
        PersonalDetailStep.new(
          first_name: 'John',
          last_name: 'Doe',
          date_of_birth: Date.new(1990, 1, 1),
        )
      end

      it 'returns success: true' do
        result = validator.execute

        expect(result[:success]).to be true
      end

      it 'does not include errors in result' do
        result = validator.execute

        expect(result).not_to have_key(:errors)
      end

      it 'only has success key' do
        result = validator.execute

        expect(result.keys).to eq([:success])
      end
    end

    context 'when step is invalid' do
      let(:step) do
        PersonalDetailStep.new(
          first_name: '',
          last_name: '',
          date_of_birth: nil,
        )
      end

      it 'returns success: false' do
        result = validator.execute

        expect(result[:success]).to be false
      end

      it 'includes errors hash' do
        result = validator.execute

        expect(result).to have_key(:errors)
      end

      it 'error hash contains field messages' do
        result = validator.execute

        expect(result[:errors]).to include(:first_name, :last_name, :date_of_birth)
      end

      it 'error messages are arrays' do
        result = validator.execute

        expect(result[:errors][:first_name]).to be_a(Array)
        expect(result[:errors][:first_name]).not_to be_empty
      end
    end

    context 'with missing first_name only' do
      let(:step) do
        PersonalDetailStep.new(
          first_name: '',
          last_name: 'Doe',
          date_of_birth: Date.new(1990, 1, 1),
        )
      end

      it 'returns false' do
        result = validator.execute

        expect(result[:success]).to be false
      end

      it 'includes error for first_name' do
        result = validator.execute

        expect(result[:errors]).to have_key(:first_name)
      end

      it 'last_name has no error' do
        result = validator.execute

        expect(result[:errors]).not_to have_key(:last_name)
      end
    end

    context 'with name too long' do
      let(:step) do
        PersonalDetailStep.new(
          first_name: 'A' * 101,
          last_name: 'Doe',
          date_of_birth: Date.new(1990, 1, 1),
        )
      end

      it 'returns false' do
        result = validator.execute

        expect(result[:success]).to be false
      end

      it 'includes error for first_name length' do
        result = validator.execute

        expect(result[:errors]).to have_key(:first_name)
      end
    end

    context 'with valid names but missing date' do
      let(:step) do
        PersonalDetailStep.new(
          first_name: 'Jane',
          last_name: 'Smith',
          date_of_birth: nil,
        )
      end

      it 'returns false' do
        result = validator.execute

        expect(result[:success]).to be false
      end

      it 'only has error for date_of_birth' do
        result = validator.execute

        expect(result[:errors].messages.keys).to eq([:date_of_birth])
      end
    end
  end

  describe '#rollback' do
    let(:step) do
      PersonalDetailStep.new(
        first_name: 'John',
        last_name: 'Doe',
        date_of_birth: Date.new(1990, 1, 1),
      )
    end

    it 'does nothing (no-op)' do
      # Rollback should be a no-op for validation
      expect { validator.rollback }.not_to raise_error
    end

    it 'does not modify repository' do
      initial_data = repository.read
      validator.rollback
      final_data = repository.read

      expect(final_data).to eq(initial_data)
    end
  end

  describe 'integration with repository' do
    let(:step) do
      PersonalDetailStep.new(
        first_name: 'Alice',
        last_name: 'Johnson',
        date_of_birth: Date.new(1985, 5, 15),
      )
    end

    it 'uses repository passed in constructor' do
      validator = described_class.new(repository:, step:)
      result = validator.execute

      expect(result[:success]).to be true
    end

    it 'does not modify repository on valid step' do
      validator = described_class.new(repository:, step:)
      validator.execute

      expect(repository.read).to be_empty
    end

    it 'works with repository.execute_operation' do
      result = repository.execute_operation(operation_class: described_class, step:)

      expect(result[:success]).to be true
    end
  end

  describe 'multiple validations' do
    let(:step) do
      PersonalDetailStep.new(
        first_name: 'Bob',
        last_name: '',
        date_of_birth: nil,
      )
    end

    it 'returns all errors' do
      result = validator.execute

      expect(result[:errors].messages.keys).to include(:last_name, :date_of_birth)
    end

    it 'returns false' do
      result = validator.execute

      expect(result[:success]).to be false
    end
  end
end
