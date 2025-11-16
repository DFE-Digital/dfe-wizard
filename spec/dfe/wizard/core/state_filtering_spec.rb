RSpec.describe DfE::Wizard::Core::StateFiltering do
  let(:wizard_class) do
    Class.new do
      include DfE::Wizard::Core::StateAccess
      include DfE::Wizard::Core::StateFiltering

      attr_reader :state_store, :reachable_path

      def initialize(state_store, reachable_path = [])
        @state_store = state_store
        @reachable_path = reachable_path
      end

      def path_traversal
        @reachable_path
      end

      def raw_step_data(step_id)
        raw_data.dig(:steps, step_id) || {}
      end
    end
  end

  subject(:wizard) { wizard_class.new(state_store, reachable_path) }

  let(:state_store_class) do
    Class.new do
      include DfE::Wizard::StateStore
    end
  end

  let(:state_store) { state_store_class.new(repository: DfE::Wizard::Repository::InMemory.new) }
  let(:reachable_path) { %i[name email review] }

  before do
    state_store.save_steps(
      name: { first_name: 'John', last_name: 'Doe' },
      email: { email: 'john@example.com' },
      email_uk: { email: 'uk@example.com' },
      email_non_uk: { email: 'non-uk@example.com' },
      review: { confirmed: true },
    )
  end

  describe '#data' do
    context 'with reachable steps' do
      it 'returns only steps in current path' do
        result = wizard.data

        expect(result[:steps]).to include(:name, :email, :review)
      end

      it 'excludes unreachable steps' do
        result = wizard.data

        expect(result[:steps]).not_to include(:email_uk, :email_non_uk)
      end

      it 'preserves step data for reachable steps' do
        result = wizard.data

        expect(result[:steps][:email]).to eq({ email: 'john@example.com' })
      end
    end

    context 'with empty path' do
      let(:reachable_path) { [] }

      it 'returns empty steps' do
        expect(wizard.data[:steps]).to be_empty
      end
    end

    context 'with all steps reachable' do
      let(:reachable_path) { %i[name email email_uk email_non_uk review] }

      it 'returns all steps' do
        result = wizard.data

        expect(result[:steps]).to include(
          :name, :email, :email_uk, :email_non_uk, :review
        )
      end
    end
  end

  describe '#step_data' do
    context 'when step is reachable and has data' do
      it 'returns step data' do
        expect(wizard.step_data(:email)).to eq({ email: 'john@example.com' })
      end
    end

    context 'when step is reachable but empty' do
      before do
        state_store.write({ steps: { empty_step: {} } })
      end

      let(:reachable_path) { [:empty_step] }

      it 'returns empty hash' do
        expect(wizard.step_data(:empty_step)).to eq({})
      end
    end

    context 'when step is unreachable' do
      it 'returns empty hash' do
        expect(wizard.step_data(:email_uk)).to eq({})
      end
    end

    context 'when step does not exist' do
      it 'returns empty hash' do
        expect(wizard.step_data(:nonexistent)).to eq({})
      end
    end
  end

  describe '#step_data_present?' do
    context 'when step is reachable and has data' do
      it 'returns true' do
        expect(wizard.step_data_present?(:email)).to be true
      end
    end

    context 'when step is reachable but empty' do
      before do
        state_store.write({ steps: { empty_step: {} } })
      end

      let(:reachable_path) { [:empty_step] }

      it 'returns false' do
        expect(wizard.step_data_present?(:empty_step)).to be false
      end
    end

    context 'when step is unreachable (has data but not in path)' do
      it 'returns false' do
        expect(wizard.step_data_present?(:email_uk)).to be false
      end
    end

    context 'when step does not exist' do
      it 'returns false' do
        expect(wizard.step_data_present?(:nonexistent)).to be false
      end
    end
  end

  describe '#all_steps_data' do
    it 'returns all reachable steps with data' do
      result = wizard.all_steps_data

      expect(result).to include(:name, :email, :review)
      expect(result).not_to include(:email_uk, :email_non_uk)
    end

    context 'with only_visited: true' do
      before do
        state_store.write({
                            steps: { empty_visited: {} },
                          })
      end

      let(:reachable_path) { %i[name email review empty_visited] }

      it 'excludes empty steps' do
        result = wizard.all_steps_data(only_visited: true)

        expect(result).not_to include(:empty_visited)
        expect(result).to include(:name, :email, :review)
      end
    end

    context 'with only_visited: false' do
      before do
        state_store.write({
                            steps: { empty_step: {} },
                          })
      end

      let(:reachable_path) { %i[name email empty_step] }

      it 'includes empty steps' do
        result = wizard.all_steps_data(only_visited: false)

        expect(result).to include(:empty_step)
      end
    end
  end

  describe '#orphaned_steps_data' do
    context 'with unreachable branches' do
      it 'returns steps not in current path' do
        result = wizard.orphaned_steps_data

        expect(result).to include(:email_uk, :email_non_uk)
      end

      it 'excludes reachable steps' do
        result = wizard.orphaned_steps_data

        expect(result).not_to include(:name, :email, :review)
      end
    end

    context 'with no unreachable steps' do
      let(:reachable_path) { %i[name email email_uk email_non_uk review] }

      it 'returns empty hash' do
        expect(wizard.orphaned_steps_data).to be_empty
      end
    end

    context 'when user switches paths' do
      before do
        wizard.instance_variable_set(:@reachable_path, %i[name email_non_uk review])
      end

      it 'shows uk path as orphaned' do
        orphaned = wizard.orphaned_steps_data

        expect(orphaned).to include(:email_uk)
        expect(orphaned).not_to include(:email_non_uk)
      end
    end
  end

  describe '#filter_to_reachable_steps' do
    it 'filters hash to only reachable steps' do
      filtered = wizard.send(:filter_to_reachable_steps, wizard.raw_data)

      expect(filtered[:steps]).to include(:name, :email, :review)
      expect(filtered[:steps]).not_to include(:email_uk, :email_non_uk)
    end

    context 'with nil input' do
      it 'returns empty hash' do
        result = wizard.send(:filter_to_reachable_steps, nil)

        expect(result).to eq({})
      end
    end

    context 'with non-hash input' do
      it 'returns empty hash' do
        result = wizard.send(:filter_to_reachable_steps, 'not a hash')

        expect(result).to eq({})
      end
    end

    context 'with metadata' do
      before do
        state_store.write({ user_id: 1, timestamp: '2025-11-15' })
      end

      it 'preserves non-step data' do
        filtered = wizard.send(:filter_to_reachable_steps, wizard.raw_data)

        expect(filtered[:user_id]).to eq(1)
        expect(filtered[:timestamp]).to eq('2025-11-15')
      end
    end
  end

  describe 'workflow: path switching' do
    it 'handles user changing path mid-wizard' do
      wizard.instance_variable_set(:@reachable_path, %i[name email_non_uk review])
      expect(wizard.step_data(:email_non_uk)).to eq({ email: 'non-uk@example.com' })
      expect(wizard.step_data(:email_uk)).to eq({})

      wizard.instance_variable_set(:@reachable_path, %i[name email_uk review])
      expect(wizard.step_data(:email_uk)).to eq({ email: 'uk@example.com' })
      expect(wizard.step_data(:email_non_uk)).to eq({})

      expect(wizard.orphaned_steps_data).to include(:email_non_uk)
    end
  end
end
