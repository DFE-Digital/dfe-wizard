# frozen_string_literal: true

require 'spec_helper'

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

      context 'when session has data' do
        before do
          session[:wizard_store] = { 'steps' => { 'name' => { 'first_name' => 'John' } } }
        end

        it 'returns the stored data' do
          expect(repository.read[:steps][:name][:first_name]).to eq('John')
        end

        it 'allows access via string keys' do
          expect(repository.read['steps']['name']['first_name']).to eq('John')
        end

        it 'allows access via symbol keys' do
          expect(repository.read[:steps][:name][:first_name]).to eq('John')
        end

        it 'allows mixed string/symbol access' do
          expect(repository.read['steps'][:name]['first_name']).to eq('John')
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

      context 'when state_key has data' do
        before do
          session[:wizard_store] = {
            'app_123' => { 'steps' => { 'name' => { 'first_name' => 'John' } } },
            'app_456' => { 'steps' => { 'name' => { 'first_name' => 'Jane' } } },
          }
        end

        it 'returns only the data for this state_key' do
          expect(repository.read[:steps][:name][:first_name]).to eq('John')
        end

        it 'allows symbol access to string-stored data' do
          expect(repository.read[:steps][:name][:first_name]).to eq('John')
        end

        it 'allows string access to string-stored data' do
          expect(repository.read['steps']['name']['first_name']).to eq('John')
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
        repository.write(steps: { name: { first_name: 'John' } })
        expect(session[:wizard_store].keys).to all(be_a(String))
      end

      it 'allows reading with symbols after writing with symbols' do
        repository.write(steps: { name: { first_name: 'John' } })
        expect(repository.read[:steps][:name][:first_name]).to eq('John')
      end

      it 'allows reading with strings after writing with symbols' do
        repository.write(steps: { name: { first_name: 'John' } })
        expect(repository.read['steps']['name']['first_name']).to eq('John')
      end

      it 'accepts string keys in write' do
        repository.write('steps' => { 'name' => { 'first_name' => 'John' } })
        expect(repository.read[:steps][:name][:first_name]).to eq('John')
      end

      it 'allows reading with symbols after writing with strings' do
        repository.write('steps' => { 'name' => { 'first_name' => 'John' } })
        expect(repository.read[:steps][:name][:first_name]).to eq('John')
      end

      it 'handles mixed symbol/string keys in nested hashes' do
        repository.write(
          'steps' => {
            name: { 'first_name' => 'John', last_name: 'Doe' },
          },
        )
        expect(repository.read[:steps][:name][:first_name]).to eq('John')
        expect(repository.read[:steps][:name][:last_name]).to eq('Doe')
      end
    end

    context 'without state_key (single instance)' do
      it 'initializes session key if not present' do
        repository.write(steps: { name: { first_name: 'John' } })
        expect(session[:wizard_store]['steps']['name']['first_name']).to eq('John')
      end

      it 'deep merges with existing data' do
        session[:wizard_store] = { 'steps' => { 'name' => { 'first_name' => 'John' } } }
        repository.write(steps: { email: { email: 'john@example.com' } })

        expect(repository.read[:steps][:name][:first_name]).to eq('John')
        expect(repository.read[:steps][:email][:email]).to eq('john@example.com')
      end
    end

    context 'with state_key (multiple instances)' do
      let(:state_key) { 'app_123' }

      it 'stores data with string keys' do
        repository.write(steps: { name: { first_name: 'John' } })
        expect(session[:wizard_store]['app_123'].keys).to all(be_a(String))
      end

      it 'initializes state_key if not present' do
        repository.write(steps: { name: { first_name: 'John' } })
        expect(repository.read[:steps][:name][:first_name]).to eq('John')
      end

      it 'deep merges with existing state_key data' do
        session[:wizard_store] = {
          'app_123' => { 'steps' => { 'name' => { 'first_name' => 'John' } } },
        }
        repository.write(steps: { email: { email: 'john@example.com' } })

        expect(repository.read[:steps][:name][:first_name]).to eq('John')
        expect(repository.read[:steps][:email][:email]).to eq('john@example.com')
      end

      it 'does not affect other state_keys' do
        session[:wizard_store] = {
          'app_123' => { 'steps' => { 'name' => { 'first_name' => 'John' } } },
          'app_456' => { 'steps' => { 'name' => { 'first_name' => 'Jane' } } },
        }
        repository.write(steps: { email: { email: 'john@example.com' } })

        repo2 = described_class.new(session:, key:, state_key: 'app_456')
        expect(repo2.read[:steps][:name][:first_name]).to eq('Jane')
        expect(repo2.read[:steps]).not_to have_key(:email)
      end
    end
  end

  describe '#save' do
    context 'string/symbol key handling' do
      it 'stores symbol keys as strings' do
        repository.save(steps: { name: { first_name: 'John' } })
        expect(session[:wizard_store].keys).to all(be_a(String))
      end

      it 'allows symbol access after save' do
        repository.save(steps: { name: { first_name: 'John' } })
        expect(repository.read[:steps][:name][:first_name]).to eq('John')
      end

      it 'allows string access after save' do
        repository.save(steps: { name: { first_name: 'John' } })
        expect(repository.read['steps']['name']['first_name']).to eq('John')
      end
    end

    context 'without state_key (single instance)' do
      it 'replaces entire state atomically' do
        session[:wizard_store] = { 'steps' => { 'name' => { 'first_name' => 'John' } } }
        repository.save(steps: { email: { email: 'new@example.com' } })

        expect(repository.read[:steps]).not_to have_key(:name)
        expect(repository.read[:steps][:email][:email]).to eq('new@example.com')
      end
    end

    context 'with state_key (multiple instances)' do
      let(:state_key) { 'app_123' }

      it 'replaces only this state_key data' do
        session[:wizard_store] = {
          'app_123' => { 'steps' => { 'name' => { 'first_name' => 'John' } } },
          'app_456' => { 'steps' => { 'name' => { 'first_name' => 'Jane' } } },
        }
        repository.save(steps: { email: { email: 'new@example.com' } })

        expect(repository.read[:steps]).not_to have_key(:name)
        expect(repository.read[:steps][:email][:email]).to eq('new@example.com')
      end

      it 'does not affect other state_keys' do
        session[:wizard_store] = {
          'app_123' => { 'steps' => { 'name' => { 'first_name' => 'John' } } },
          'app_456' => { 'steps' => { 'name' => { 'first_name' => 'Jane' } } },
        }
        repository.save(steps: { email: { email: 'new@example.com' } })

        repo2 = described_class.new(session:, key:, state_key: 'app_456')
        expect(repo2.read[:steps][:name][:first_name]).to eq('Jane')
      end

      it 'stores a deep copy' do
        data = { steps: { name: { first_name: 'John' } } }
        repository.save(data)
        data[:steps][:name][:first_name] = 'Jane'

        expect(repository.read[:steps][:name][:first_name]).to eq('John')
      end
    end
  end

  describe '#clear' do
    context 'without state_key (single instance)' do
      before do
        session[:wizard_store] = { 'steps' => { 'name' => { 'first_name' => 'John' } } }
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
          'app_123' => { 'steps' => { 'name' => { 'first_name' => 'John' } } },
          'app_456' => { 'steps' => { 'name' => { 'first_name' => 'Jane' } } },
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

      it 'preserves the wizard_store key itself' do
        repository.clear
        expect(session[:wizard_store]).to be_present
      end
    end
  end

  describe 'multiple wizard instances' do
    let(:repo1) { described_class.new(session:, key: :wizard_store, state_key: 'app_123') }
    let(:repo2) { described_class.new(session:, key: :wizard_store, state_key: 'app_456') }

    it 'keeps data isolated per state_key' do
      repo1.save(steps: { name: { first_name: 'John' } })
      repo2.save(steps: { name: { first_name: 'Jane' } })

      expect(repo1.read[:steps][:name][:first_name]).to eq('John')
      expect(repo2.read[:steps][:name][:first_name]).to eq('Jane')
    end

    it 'allows symbol access across all instances' do
      repo1.save(steps: { name: { first_name: 'John' } })
      repo2.save(steps: { name: { first_name: 'Jane' } })

      expect(repo1.read[:steps][:name][:first_name]).to eq('John')
      expect(repo2.read[:steps][:name][:first_name]).to eq('Jane')
    end

    it 'allows independent operations' do
      repo1.write(steps: { name: { first_name: 'John' } })
      repo2.write(steps: { email: { email: 'jane@example.com' } })

      expect(repo1.read[:steps]).to have_key(:name)
      expect(repo1.read[:steps]).not_to have_key(:email)
      expect(repo2.read[:steps]).to have_key(:email)
      expect(repo2.read[:steps]).not_to have_key(:name)
    end

    it 'allows independent clearing' do
      repo1.save(steps: { name: { first_name: 'John' } })
      repo2.save(steps: { name: { first_name: 'Jane' } })

      repo1.clear

      expect(repo1.read).to eq({})
      expect(repo2.read[:steps][:name][:first_name]).to eq('Jane')
    end
  end

  describe 'mixed key and state_key scenarios' do
    let(:single_wizard) { described_class.new(session:, key: :wizard_a) }
    let(:multi_wizard_1) { described_class.new(session:, key: :wizard_b, state_key: 'instance_1') }
    let(:multi_wizard_2) { described_class.new(session:, key: :wizard_b, state_key: 'instance_2') }

    it 'allows different wizards with different patterns' do
      single_wizard.save(steps: { a: { value: 1 } })
      multi_wizard_1.save(steps: { b: { value: 2 } })
      multi_wizard_2.save(steps: { c: { value: 3 } })

      expect(single_wizard.read[:steps][:a][:value]).to eq(1)
      expect(multi_wizard_1.read[:steps][:b][:value]).to eq(2)
      expect(multi_wizard_2.read[:steps][:c][:value]).to eq(3)
    end

    it 'stores all data as strings internally' do
      single_wizard.save(steps: { a: { value: 1 } })
      multi_wizard_1.save(steps: { b: { value: 2 } })

      expect(session[:wizard_a].keys).to all(be_a(String))
      expect(session[:wizard_b]['instance_1'].keys).to all(be_a(String))
    end
  end

  describe 'DoS protection' do
    it 'does not create symbols from user input' do
      user_input = { 'user_controlled_key' => { 'nested' => 'value' } }
      repository.write(user_input)

      expect(session[:wizard_store].keys).to all(be_a(String))
      expect(Symbol.all_symbols.map(&:to_s)).not_to include('user_controlled_key')
    end

    it 'handles deeply nested user input safely' do
      user_input = {
        'level1' => {
          'level2' => {
            'level3' => {
              'user_key' => 'value',
            },
          },
        },
      }
      repository.write(user_input)

      expect(session[:wizard_store]['level1']['level2']['level3']['user_key']).to eq('value')
    end
  end
end
