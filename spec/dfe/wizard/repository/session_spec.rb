RSpec.describe DfE::Wizard::Repository::Session do
  let(:session) { {} }
  let(:repository) { described_class.new(session:) }

  describe '#initialize' do
    it 'accepts session and default key' do
      expect(repository.session).to eq(session)
      expect(repository.key).to eq(:wizard_store)
    end

    it 'accepts custom key' do
      custom_repository = described_class.new(session:, key: :custom_key)
      expect(custom_repository.key).to eq(:custom_key)
    end

    it 'accepts state_key for multi-wizard' do
      multi_repository = described_class.new(session:, state_key: 'wizard_1')
      expect(multi_repository.state_key).to eq('wizard_1')
    end
  end

  describe 'encryption behavior' do
    include_examples 'repository encryption'
    let(:unencrypted_repository) do
      build_repository(key: 'wizard:1', encrypted: false, encryptor: nil)
    end
    let(:encrypted_repository) do
      build_repository(key: 'wizard:2', encrypted: true, encryptor:)
    end

    def build_repository(key: 'wizard_state', encrypted: false, encryptor: nil)
      described_class.new(session:, key:, encrypted:, encryptor:)
    end
  end

  describe '#read' do
    context 'with no data' do
      it 'returns empty hash' do
        expect(repository.read).to eq({})
      end
    end

    context 'with saved data' do
      before do
        session[:wizard_store] = { 'name' => 'John', 'email' => 'john@example.com' }
      end

      it 'returns data with indifferent access' do
        data = repository.read
        expect(data[:name]).to eq('John')
        expect(data['name']).to eq('John')
      end
    end

    context 'with state_key' do
      let(:repository) { described_class.new(session:, state_key: 'wizard_1') }

      before do
        session[:wizard_store] = {
          'wizard_1' => { 'name' => 'John' },
          'wizard_2' => { 'name' => 'Jane' },
        }
      end

      it 'returns only data for specified state_key' do
        expect(repository.read).to eq({ 'name' => 'John' })
      end

      it 'returns empty hash if state_key not found' do
        multi_repository = described_class.new(session:, state_key: 'wizard_3')
        expect(multi_repository.read).to eq({})
      end
    end
  end

  describe '#write' do
    it 'merges data into session' do
      repository.write({ name: 'John' })
      repository.write({ email: 'john@example.com' })

      expect(session[:wizard_store]).to include('name' => 'John', 'email' => 'john@example.com')
    end

    context 'with state_key' do
      let(:repository) { described_class.new(session:, state_key: 'wizard_1') }

      it 'stores data under state_key' do
        repository.write({ name: 'John' })

        expect(session[:wizard_store]['wizard_1']).to include('name' => 'John')
      end

      it 'preserves other state_keys' do
        session[:wizard_store] = { 'wizard_2' => { 'name' => 'Jane' } }
        repository.write({ email: 'john@example.com' })

        expect(session[:wizard_store]['wizard_2']).to eq({ 'name' => 'Jane' })
        expect(session[:wizard_store]['wizard_1']).to include('email' => 'john@example.com')
      end
    end
  end

  describe '#save' do
    it 'replaces entire data' do
      session[:wizard_store] = { 'name' => 'John', 'email' => 'john@example.com' }
      repository.save({ 'name' => 'Jane' })

      expect(session[:wizard_store]).to eq({ 'name' => 'Jane' })
    end

    context 'with state_key' do
      let(:repository) { described_class.new(session:, state_key: 'wizard_1') }

      it 'replaces only specified state' do
        session[:wizard_store] = {
          'wizard_1' => { 'name' => 'John' },
          'wizard_2' => { 'name' => 'Jane' },
        }
        repository.save({ 'name' => 'Alice' })

        expect(session[:wizard_store]['wizard_1']).to eq({ 'name' => 'Alice' })
        expect(session[:wizard_store]['wizard_2']).to eq({ 'name' => 'Jane' })
      end
    end
  end

  describe '#execute_operation' do
    class SessionTestStep
      include DfE::Wizard::Step

      attribute :name, :string
      attribute :email, :string

      validates :name, :email, presence: true
    end

    context 'with valid step' do
      let(:step) { SessionTestStep.new(name: 'John', email: 'john@example.com') }

      it 'executes operation in session context' do
        result = repository.execute_operation(
          operation_class: DfE::Wizard::Operations::Validate,
          step:,
        )

        expect(result[:success]).to be true
      end

      it 'operation can persist to session' do
        repository.execute_operation(
          operation_class: DfE::Wizard::Operations::Persist,
          step:,
        )

        expect(repository.read).to include('name' => 'John', 'email' => 'john@example.com')
      end
    end

    context 'with multiple wizards' do
      let(:repo1) { described_class.new(session:, state_key: 'wizard_1') }
      let(:repo2) { described_class.new(session:, state_key: 'wizard_2') }
      let(:step1) { SessionTestStep.new(name: 'John') }
      let(:step2) { SessionTestStep.new(name: 'Jane') }

      it 'operations maintain separate state' do
        repo1.execute_operation(operation_class: DfE::Wizard::Operations::Persist, step: step1)
        repo2.execute_operation(operation_class: DfE::Wizard::Operations::Persist, step: step2)

        expect(repo1.read['name']).to eq('John')
        expect(repo2.read['name']).to eq('Jane')
      end
    end
  end

  describe '#clear' do
    before do
      session[:wizard_store] = { 'name' => 'John', 'email' => 'john@example.com' }
    end

    it 'removes data from session' do
      repository.clear
      expect(session[:wizard_store]).to be_nil
    end

    context 'with state_key' do
      let(:repository) { described_class.new(session:, key: 'wizard_key', state_key: 'wizard_1') }

      before do
        session['wizard_key'] = {
          'wizard_1' => { 'name' => 'John' },
          'wizard_2' => { 'name' => 'Jane' },
        }
      end

      it 'removes only specified state' do
        repository.clear

        expect(session['wizard_key']).to eq(
          'wizard_2' => { 'name' => 'Jane' },
        )
      end
    end
  end
end
