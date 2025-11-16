RSpec.describe DfE::Wizard::Core::StateLifecycle do
  let(:wizard_class) do
    Class.new do
      include DfE::Wizard::Core::StateAccess
      include DfE::Wizard::Core::StateFiltering
      include DfE::Wizard::Core::StateLifecycle

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

  let(:state_store_class) do
    Class.new do
      include DfE::Wizard::StateStore
    end
  end

  subject(:wizard) { wizard_class.new(state_store, reachable_path) }

  let(:state_store) do
    state_store_class.new(repository: DfE::Wizard::Repository::InMemory.new)
  end
  let(:reachable_path) { %i[name email review] }

  before do
    state_store.save_steps(
      name: { first_name: 'John', last_name: 'Doe' },
      email: { email: 'john@example.com' },
      review: { confirmed: true },
    )
  end

  describe '#mark_completed' do
    it 'sets completed flag' do
      wizard.mark_completed

      expect(wizard.raw_data[:completed]).to be true
    end

    it 'sets completed_at timestamp' do
      before_time = Time.current
      wizard.mark_completed
      after_time = Time.current

      timestamp = wizard.raw_data[:completed_at]
      expect(timestamp).to be_between(before_time, after_time)
    end

    it 'preserves all step data' do
      wizard.mark_completed

      expect(wizard.raw_step_data(:name)).to include(first_name: 'John')
      expect(wizard.raw_step_data(:email)).to include(email: 'john@example.com')
    end

    it 'allows multiple calls (idempotent)' do
      Time.current
      wizard.mark_completed
      sleep(0.01)
      Time.current
      wizard.mark_completed

      timestamp1 = wizard.raw_data[:completed_at]
      wizard.mark_completed
      timestamp2 = wizard.raw_data[:completed_at]

      expect(timestamp1).not_to be_nil
      expect(timestamp2).not_to be_nil
    end
  end

  describe '#completed?' do
    context 'when marked completed' do
      before { wizard.mark_completed }

      it 'returns true' do
        expect(wizard.completed?).to be true
      end
    end

    context 'when not marked completed' do
      it 'returns false' do
        expect(wizard.completed?).to be false
      end
    end

    context 'with corrupted data' do
      before do
        state_store.write({ completed: false })
      end

      it 'returns false' do
        expect(wizard.completed?).to be false
      end
    end
  end

  describe '#completed_at' do
    context 'when marked completed' do
      before { wizard.mark_completed }

      it 'returns timestamp' do
        expect(wizard.completed_at).to be_a(Time)
      end
    end

    context 'when not marked completed' do
      it 'returns nil' do
        expect(wizard.completed_at).to be_nil
      end
    end
  end

  describe '#set_metadata, #get_metadata' do
    it 'stores and retrieves metadata' do
      wizard.set_metadata(:user_id, 123)
      wizard.set_metadata(:form_version, 2)

      expect(wizard.get_metadata(:user_id)).to eq(123)
      expect(wizard.get_metadata(:form_version)).to eq(2)
    end

    it 'supports default value' do
      expect(wizard.get_metadata(:missing_key, default: 'default')).to eq('default')
    end

    it 'preserves step data' do
      wizard.set_metadata(:user_id, 1)

      expect(wizard.raw_step_data(:name)).to include(first_name: 'John')
    end

    context 'with complex metadata' do
      it 'stores nested structures' do
        wizard.set_metadata(:context, { session_id: 'abc', ip: '127.0.0.1' })

        expect(wizard.get_metadata(:context)).to include(session_id: 'abc')
      end
    end
  end

  describe '#all_metadata' do
    it 'returns all non-step data' do
      wizard.set_metadata(:user_id, 1)
      wizard.set_metadata(:submitted_at, Time.current)
      wizard.mark_completed

      metadata = wizard.all_metadata

      expect(metadata).to include(:user_id, :completed, :completed_at)
      expect(metadata).not_to include(:steps)
    end

    context 'when no metadata exists' do
      it 'returns empty hash' do
        expect(wizard.all_metadata).to eq({})
      end
    end
  end

  describe '#export' do
    before do
      state_store.write(
        {
          steps: {
            email_uk: { email: 'uk@example.com' },
          },
          metadata: { user_id: 1 },
        },
      )

      wizard.instance_variable_set(:@reachable_path, %i[name email review])
    end

    it 'exports reachable data with metadata by default' do
      export = wizard.export

      expect(export[:steps]).to include(:name, :email, :review)
      expect(export[:steps]).not_to include(:email_uk)
      expect(export[:metadata]).to eq({ user_id: 1 })
    end

    context 'with include_metadata: false' do
      it 'excludes metadata' do
        export = wizard.export(include_metadata: false)

        expect(export).to have_key(:steps)
        expect(export).not_to have_key(:metadata)
      end
    end

    context 'with only_visited: true' do
      before do
        state_store.write(
          {
            steps: { empty_step: {} },
          },
        )
        wizard.instance_variable_set(:@reachable_path, %i[name email review empty_step])
      end

      it 'excludes empty steps' do
        export = wizard.export(only_visited: true)

        expect(export[:steps]).not_to include(:empty_step)
      end
    end

    context 'with include_orphaned: true' do
      it 'includes unreachable branch data' do
        export = wizard.export(include_orphaned: true)

        expect(export[:steps]).to include(:email_uk)
      end
    end

    it 'combines all options' do
      export = wizard.export(
        include_metadata: true,
        only_visited: false,
        include_orphaned: true,
      )

      expect(export[:steps]).to include(:name, :email, :review, :email_uk)
      expect(export).to include(:metadata)
    end
  end

  describe '#state_summary' do
    it 'provides diagnostic summary' do
      wizard.set_metadata(:user_id, 1)
      wizard.mark_completed

      summary = wizard.state_summary

      expect(summary).to include(
        steps_reachable: 3,
        steps_with_data_reachable: 3,
        completed: true,
      )
      expect(summary[:completed_at]).not_to be_nil
    end

    context 'with orphaned steps' do
      before do
        state_store.write(
          {
            steps: {
              email_uk: { email: 'uk@example.com' },
            },
          },
        )
      end

      it 'shows orphaned step count' do
        summary = wizard.state_summary

        expect(summary[:orphaned_steps]).to eq(1)
      end
    end

    context 'with empty steps' do
      before do
        state_store.write(
          {
            steps: { empty_step: {} },
          },
        )
        wizard.instance_variable_set(:@reachable_path, %i[name email review empty_step])
      end

      it 'counts steps with data separately' do
        summary = wizard.state_summary

        expect(summary[:steps_reachable]).to eq(4)
        expect(summary[:steps_with_data_reachable]).to eq(3)
      end
    end
  end

  describe '#state_store_available?' do
    it 'returns true when state store has read method' do
      expect(wizard.state_store_available?).to be true
    end

    context 'with nil state store' do
      subject(:wizard) { wizard_class.new(nil) }

      it 'returns false' do
        expect(wizard.state_store_available?).to be false
      end
    end
  end

  describe 'workflow: full lifecycle' do
    it 'handles complete wizard journey' do
      wizard.set_metadata(:user_id, 1)
      expect(wizard.get_metadata(:user_id)).to eq(1)

      expect(wizard.raw_step_data(:name)).to include(first_name: 'John')

      export = wizard.export
      expect(export[:steps]).to include(:name, :email, :review)

      wizard.mark_completed
      expect(wizard.completed?).to be true

      summary = wizard.state_summary
      expect(summary[:completed]).to be true
      expect(summary[:steps_reachable]).to eq(3)

      expect(wizard.get_metadata(:user_id)).to eq(1)
      expect(wizard.raw_step_data(:email)).to include(email: 'john@example.com')
    end
  end
end
