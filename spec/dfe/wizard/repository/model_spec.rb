RSpec.describe DfE::Wizard::Repository::Model do
  let(:record) { create(:user) }
  let(:repository) { described_class.new(record:) }

  describe '#initialize' do
    it 'requires record' do
      expect { described_class.new(record: nil) }.to raise_error(ArgumentError)
    end

    it 'stores record reference' do
      expect(repository.record).to eq(record)
    end
  end

  describe '#read' do
    before do
      record.first_name = 'John'
      record.last_name = 'Doe'
      record.email = 'john@example.com'
    end

    it 'returns model attributes' do
      data = repository.read
      expect(data).to include(first_name: 'John', last_name: 'Doe')
    end

    it 'excludes excluded_columns' do
      allow_any_instance_of(described_class).to receive(:excluded_columns).and_return([:password_digest])
      data = repository.read
      expect(data).not_to have_key(:password_digest)
    end
  end

  describe '#write' do
    it 'assigns writable attributes to model' do
      repository.write({ first_name: 'Jane', email: 'jane@example.com' })

      expect(record.first_name).to eq('Jane')
      expect(record.email).to eq('jane@example.com')
    end

    it 'only writes whitelisted attributes' do
      email = record.email
      allow_any_instance_of(described_class).to receive(:writable_attributes).and_return([:first_name])

      repository.write({ first_name: 'Jane', email: 'ignored@gmail.com' })

      expect(record.first_name).to eq('Jane')
      expect(record.email).to eq(email)
    end
  end

  describe '#execute_operation' do
    class ModelTestStep
      include DfE::Wizard::Step

      attribute :name, :string
      attribute :email, :string

      validates :name, :email, presence: true
    end

    context 'with valid step' do
      let(:step) { ModelTestStep.new(name: 'John Doe', email: 'john.doe@gmail.com') }

      it 'executes operation in model context' do
        result = repository.execute_operation(
          operation_class: DfE::Wizard::Operations::Validate,
          step:,
        )

        expect(result[:success]).to be true
      end
    end

    context 'with invalid step' do
      let(:step) { ModelTestStep.new }

      it 'returns validation errors' do
        result = repository.execute_operation(
          operation_class: DfE::Wizard::Operations::Validate,
          step:,
        )

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end
    end
  end

  describe '#clear' do
    it 'raises NotImplementedError' do
      expect { repository.clear }.to raise_error(NotImplementedError)
    end
  end

  describe 'hooks' do
    describe '#transform_for_read' do
      it 'defaults to identity transformation' do
        data = { name: 'John' }
        expect(repository.transform_for_read(data)).to eq(data)
      end
    end

    describe '#transform_for_write' do
      it 'defaults to identity transformation' do
        data = { name: 'John' }
        expect(repository.transform_for_write(data)).to eq(data)
      end
    end

    describe '#excluded_columns' do
      it 'returns empty array by default' do
        expect(repository.excluded_columns).to eq([])
      end
    end

    describe '#readable_attributes' do
      it 'returns all columns except excluded' do
        allow_any_instance_of(described_class).to receive(:excluded_columns).and_return([:password_digest])
        attrs = repository.readable_attributes

        expect(attrs).not_to include(:password_digest)
      end
    end

    describe '#writable_attributes' do
      it 'defaults to readable_attributes' do
        expect(repository.writable_attributes).to eq(repository.readable_attributes)
      end
    end
  end
end
