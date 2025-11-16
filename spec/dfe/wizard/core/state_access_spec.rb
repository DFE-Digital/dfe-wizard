RSpec.describe DfE::Wizard::Core::StateAccess do
  let(:wizard_class) do
    Class.new do
      include DfE::Wizard::Core::StateAccess

      attr_reader :state_store, :current_step

      def initialize(state_store)
        @state_store = state_store
        @current_step = OpenStruct.new(serializable_data: { email: 'test@example.com' })
      end

      def current_step_name
        :email
      end
    end
  end

  let(:state_store_class) do
    Class.new do
      include DfE::Wizard::StateStore
    end
  end

  subject(:wizard) { wizard_class.new(state_store) }

  let(:state_store) { state_store_class.new(repository: DfE::Wizard::Repository::InMemory.new) }

  describe '#raw_data' do
    context 'when repository is empty' do
      it 'returns empty hash' do
        expect(wizard.raw_data).to eq({})
      end
    end

    context 'when repository has data' do
      before do
        state_store.save(
          {
            steps: {
              name: { first_name: 'John', last_name: 'Doe' },
              email: { email: 'john@example.com' },
            },
            metadata: { user_id: 1 },
          },
        )
      end

      it 'returns all data unfiltered' do
        expect(wizard.raw_data).to include(
          steps: hash_including(:name, :email),
          metadata: { user_id: 1 },
        )
      end

      it 'includes unreachable branches' do
        state_store.write(
          {
            steps: {
              email_uk: { email: 'uk@example.com' },
              email_non_uk: { email: 'non-uk@example.com' },
            },
          },
        )

        raw = wizard.raw_data
        expect(raw[:steps]).to include(:email_uk, :email_non_uk)
      end
    end
  end

  describe '#raw_step_data' do
    context 'when step exists' do
      before do
        state_store.save(
          {
            steps: { name: { first_name: 'John', last_name: 'Doe' } },
          },
        )
      end

      it 'returns step data' do
        expect(wizard.raw_step_data(:name)).to eq(
          {
            first_name: 'John',
            last_name: 'Doe',
          },
        )
      end
    end

    context 'when step does not exist' do
      it 'returns empty hash' do
        expect(wizard.raw_step_data(:nonexistent)).to eq({})
      end
    end

    context 'when no steps exist' do
      it 'returns empty hash' do
        state_store.save({})

        expect(wizard.raw_step_data(:any)).to eq({})
      end
    end
  end

  describe '#step_data_exists?' do
    context 'when step has data' do
      before do
        state_store.save(
          {
            steps: { name: { first_name: 'John' } },
          },
        )
      end

      it 'returns true' do
        expect(wizard.step_data_exists?(:name)).to be true
      end
    end

    context 'when step is empty' do
      before do
        state_store.save(
          {
            steps: { email: {} },
          },
        )
      end

      it 'returns false' do
        expect(wizard.step_data_exists?(:email)).to be false
      end
    end

    context 'when step does not exist' do
      it 'returns false' do
        expect(wizard.step_data_exists?(:nonexistent)).to be false
      end
    end

    context 'with unreachable branches' do
      before do
        state_store.save(
          {
            steps: {
              email_uk: { email: 'uk@example.com' },
              email_non_uk: {},
            },
          },
        )
      end

      it 'returns true regardless of reachability' do
        expect(wizard.step_data_exists?(:email_uk)).to be true
      end
    end
  end

  describe '#save' do
    it 'saves current step data to state store' do
      wizard.save

      expect(state_store.read[:steps][:email]).to eq({ email: 'test@example.com' })
    end

    context 'with existing data' do
      before do
        state_store.save(
          {
            steps: { name: { first_name: 'John' } },
          },
        )
      end

      it 'adds new step without affecting existing' do
        wizard.save

        expect(state_store.read[:steps][:name]).to eq({ first_name: 'John' })
        expect(state_store.read[:steps][:email]).to eq({ email: 'test@example.com' })
      end
    end

    context 'with multiple calls' do
      it 'overwrites previous step data' do
        wizard.save
        allow(wizard.current_step).to receive(:serializable_data).and_return({ email: 'new@example.com' })
        wizard.save

        expect(state_store.read[:steps][:email][:email]).to eq('new@example.com')
      end
    end
  end

  describe '#write_state' do
    it 'writes arbitrary data to state store' do
      wizard.write_state({ user_id: 1, timestamp: '2025-11-15' })

      expect(state_store.read).to include(
        user_id: 1,
        timestamp: '2025-11-15',
      )
    end

    context 'with existing data' do
      before do
        state_store.save(
          {
            steps: { name: { first_name: 'John' } },
          },
        )
      end

      it 'deep merges with existing state' do
        wizard.write_state({ user_id: 1 })

        expect(state_store.read[:steps]).to include(name: { first_name: 'John' })
        expect(state_store.read[:user_id]).to eq(1)
      end
    end

    context 'with nested metadata' do
      it 'handles nested updates' do
        wizard.write_state({ metadata: { form_version: 2 } })
        wizard.write_state({ metadata: { user_agent: 'Mozilla' } })

        expect(state_store.read[:metadata]).to include(
          form_version: 2,
          user_agent: 'Mozilla',
        )
      end
    end
  end

  describe '#clear_state' do
    before do
      state_store.save(
        {
          steps: { name: { first_name: 'John' }, email: { email: 'john@example.com' } },
          metadata: { user_id: 1 },
        },
      )
    end

    it 'removes all data' do
      wizard.clear_state

      expect(state_store.read).to eq({})
    end

    it 'allows subsequent saves' do
      wizard.clear_state
      wizard.write_state({ new_key: 'value' })

      expect(state_store.read).to eq({ new_key: 'value' })
    end

    context 'when already empty' do
      before { state_store.clear }

      it 'handles gracefully' do
        expect { wizard.clear_state }.not_to raise_error
      end
    end
  end

  describe 'workflow' do
    it 'handles typical step-by-step save flow' do
      wizard.save
      expect(wizard.raw_step_data(:email)).to eq({ email: 'test@example.com' })

      wizard.write_state({ submitted_at: Time.now })
      expect(wizard.raw_data[:submitted_at]).not_to be_nil

      expect(wizard.step_data_exists?(:email)).to be true

      wizard.clear_state
      expect(wizard.raw_data).to eq({})
    end
  end
end
