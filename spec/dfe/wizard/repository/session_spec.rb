RSpec.describe DfE::Wizard::Repository::Session do
  let(:session) { {} }
  let(:key) { :wizard_store }
  let(:state_key) { nil }
  let(:repository) { described_class.new(session:, key:, state_key:) }

  describe '#initialize' do
    it 'accepts session, key, and state_key' do
      repo = described_class.new(session: {}, key: :custom_key, state_key: 'app_123')
      expect(repo.session).to eq({})
      expect(repo.key).to eq(:custom_key)
      expect(repo.state_key).to eq('app_123')
    end

    it 'defaults state_key to nil' do
      repo = described_class.new(session: {}, key:)
      expect(repo.state_key).to be_nil
    end
  end

  describe '#read' do
    context 'without state_key (single instance)' do
      context 'when session is empty' do
        it 'returns empty hash' do
          expect(repository.read).to eq({})
        end

        it 'returns HashWithIndifferentAccess' do
          expect(repository.read).to be_a(ActiveSupport::HashWithIndifferentAccess)
        end
      end

      context 'when session has flat data' do
        before do
          session[:wizard_store] = { 'first_name' => 'John', 'last_name' => 'Doe', 'email' => 'john@example.com' }
        end

        it 'returns the stored flat hash' do
          expect(repository.read[:first_name]).to eq('John')
          expect(repository.read[:email]).to eq('john@example.com')
        end

        it 'allows access via string keys' do
          expect(repository.read['first_name']).to eq('John')
        end

        it 'allows access via symbol keys' do
          expect(repository.read[:first_name]).to eq('John')
        end
      end
    end

    context 'with state_key (multiple instances)' do
      let(:state_key) { 'app_123' }

      context 'when state_key has no data' do
        it 'returns empty hash' do
          expect(repository.read).to eq({})
        end

        it 'returns HashWithIndifferentAccess' do
          expect(repository.read).to be_a(ActiveSupport::HashWithIndifferentAccess)
        end
      end

      context 'when state_key has flat data' do
        before do
          session[:wizard_store] = {
            'app_123' => { 'first_name' => 'John', 'email' => 'john@example.com' },
            'app_456' => { 'first_name' => 'Jane', 'email' => 'jane@example.com' },
          }
        end

        it 'returns only the data for this state_key' do
          expect(repository.read[:first_name]).to eq('John')
          expect(repository.read[:email]).to eq('john@example.com')
        end

        it 'allows symbol access' do
          expect(repository.read[:first_name]).to eq('John')
        end

        it 'allows string access' do
          expect(repository.read['first_name']).to eq('John')
        end

        it 'does not return other state_key data' do
          expect(repository.read.keys).not_to include('app_456')
        end
      end
    end
  end

  describe '#write' do
    context 'string/symbol key handling' do
      it 'stores symbol keys as strings' do
        repository.write(first_name: 'John', last_name: 'Doe')
        expect(session[:wizard_store].keys).to all(be_a(String))
      end

      it 'allows reading with symbols after writing with symbols' do
        repository.write(first_name: 'John', email: 'john@example.com')
        expect(repository.read[:first_name]).to eq('John')
        expect(repository.read[:email]).to eq('john@example.com')
      end

      it 'allows reading with strings after writing with symbols' do
        repository.write(first_name: 'John')
        expect(repository.read['first_name']).to eq('John')
      end

      it 'accepts string keys in write' do
        repository.write('first_name' => 'John', 'last_name' => 'Doe')
        expect(repository.read[:first_name]).to eq('John')
      end
    end

    context 'without state_key (single instance)' do
      it 'initializes session key if not present' do
        repository.write(first_name: 'John', last_name: 'Doe')
        expect(session[:wizard_store]['first_name']).to eq('John')
      end

      it 'merges with existing data' do
        session[:wizard_store] = { 'first_name' => 'John', 'last_name' => 'Doe' }
        repository.write(email: 'john@example.com', city: 'London')

        expect(repository.read[:first_name]).to eq('John')
        expect(repository.read[:last_name]).to eq('Doe')
        expect(repository.read[:email]).to eq('john@example.com')
        expect(repository.read[:city]).to eq('London')
      end

      it 'updates existing attributes' do
        session[:wizard_store] = { 'first_name' => 'John', 'email' => 'old@example.com' }
        repository.write(email: 'new@example.com')

        expect(repository.read[:first_name]).to eq('John')
        expect(repository.read[:email]).to eq('new@example.com')
      end
    end

    context 'with state_key (multiple instances)' do
      let(:state_key) { 'app_123' }

      it 'stores data with string keys' do
        repository.write(first_name: 'John')
        expect(session[:wizard_store]['app_123'].keys).to all(be_a(String))
      end

      it 'initializes state_key if not present' do
        repository.write(first_name: 'John', email: 'john@example.com')
        expect(repository.read[:first_name]).to eq('John')
      end

      it 'merges with existing state_key data' do
        session[:wizard_store] = {
          'app_123' => { 'first_name' => 'John', 'last_name' => 'Doe' },
        }
        repository.write(email: 'john@example.com')

        expect(repository.read[:first_name]).to eq('John')
        expect(repository.read[:email]).to eq('john@example.com')
      end

      it 'does not affect other state_keys' do
        session[:wizard_store] = {
          'app_123' => { 'first_name' => 'John' },
          'app_456' => { 'first_name' => 'Jane' },
        }
        repository.write(email: 'john@example.com')

        repo2 = described_class.new(session:, key:, state_key: 'app_456')
        expect(repo2.read[:first_name]).to eq('Jane')
        expect(repo2.read).not_to have_key(:email)
      end
    end
  end

  describe '#save' do
    context 'string/symbol key handling' do
      it 'stores symbol keys as strings' do
        repository.save(first_name: 'John', email: 'john@example.com')
        expect(session[:wizard_store].keys).to all(be_a(String))
      end

      it 'allows symbol access after save' do
        repository.save(first_name: 'John')
        expect(repository.read[:first_name]).to eq('John')
      end

      it 'allows string access after save' do
        repository.save(first_name: 'John')
        expect(repository.read['first_name']).to eq('John')
      end
    end

    context 'without state_key (single instance)' do
      it 'replaces entire state atomically' do
        session[:wizard_store] = { 'first_name' => 'John', 'last_name' => 'Doe', 'age' => 30 }
        repository.save(email: 'new@example.com', city: 'London')

        expect(repository.read).not_to have_key(:first_name)
        expect(repository.read).not_to have_key(:age)
        expect(repository.read[:email]).to eq('new@example.com')
        expect(repository.read[:city]).to eq('London')
      end
    end

    context 'with state_key (multiple instances)' do
      let(:state_key) { 'app_123' }

      it 'replaces only this state_key data' do
        session[:wizard_store] = {
          'app_123' => { 'first_name' => 'John', 'last_name' => 'Doe' },
          'app_456' => { 'first_name' => 'Jane' },
        }
        repository.save(email: 'new@example.com')

        expect(repository.read).not_to have_key(:first_name)
        expect(repository.read[:email]).to eq('new@example.com')
      end

      it 'does not affect other state_keys' do
        session[:wizard_store] = {
          'app_123' => { 'first_name' => 'John' },
          'app_456' => { 'first_name' => 'Jane' },
        }
        repository.save(email: 'new@example.com')

        repo2 = described_class.new(session:, key:, state_key: 'app_456')
        expect(repo2.read[:first_name]).to eq('Jane')
      end

      it 'stores a deep copy' do
        data = { first_name: 'John', email: 'john@example.com' }
        repository.save(data)
        data[:first_name] = 'Jane'

        expect(repository.read[:first_name]).to eq('John')
      end
    end
  end

  describe '#clear' do
    context 'without state_key (single instance)' do
      before do
        session[:wizard_store] = { 'first_name' => 'John', 'email' => 'john@example.com' }
        session[:other_data] = 'preserved'
      end

      it 'removes entire wizard key from session' do
        repository.clear
        expect(session[:wizard_store]).to be_nil
      end

      it 'preserves other session keys' do
        repository.clear
        expect(session[:other_data]).to eq('preserved')
      end
    end

    context 'with state_key (multiple instances)' do
      let(:state_key) { 'app_123' }

      before do
        session[:wizard_store] = {
          'app_123' => { 'first_name' => 'John' },
          'app_456' => { 'first_name' => 'Jane' },
        }
      end

      it 'removes only this state_key data' do
        repository.clear
        expect(session[:wizard_store]['app_123']).to be_nil
      end

      it 'preserves other state_keys' do
        repository.clear
        expect(session[:wizard_store]['app_456']).to be_present
      end
    end
  end

  describe 'multiple wizard instances' do
    let(:repo1) { described_class.new(session:, key: :wizard_store, state_key: 'app_123') }
    let(:repo2) { described_class.new(session:, key: :wizard_store, state_key: 'app_456') }

    it 'keeps data isolated per state_key' do
      repo1.save(first_name: 'John', email: 'john@example.com')
      repo2.save(first_name: 'Jane', email: 'jane@example.com')

      expect(repo1.read[:first_name]).to eq('John')
      expect(repo2.read[:first_name]).to eq('Jane')
    end

    it 'allows independent operations' do
      repo1.write(first_name: 'John', last_name: 'Doe')
      repo2.write(email: 'jane@example.com', city: 'Paris')

      expect(repo1.read).to have_key(:first_name)
      expect(repo1.read).not_to have_key(:email)
      expect(repo2.read).to have_key(:email)
      expect(repo2.read).not_to have_key(:first_name)
    end

    it 'allows independent clearing' do
      repo1.save(first_name: 'John')
      repo2.save(first_name: 'Jane')

      repo1.clear

      expect(repo1.read).to eq({})
      expect(repo2.read[:first_name]).to eq('Jane')
    end
  end

  describe 'DoS protection' do
    it 'does not create symbols from user input' do
      user_input = { 'user_controlled_key' => 'value', 'another_key' => 'data' }
      repository.write(user_input)

      expect(session[:wizard_store].keys).to all(be_a(String))
      expect(Symbol.all_symbols.map(&:to_s)).not_to include('user_controlled_key')
    end
  end
end
