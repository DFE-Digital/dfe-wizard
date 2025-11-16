RSpec.describe DfE::Wizard::Repository::InMemory do
  subject(:repository) { described_class.new }

  describe '#read' do
    context 'when no data has been written' do
      it 'returns empty hash' do
        expect(repository.read).to eq({})
      end
    end

    context 'when data has been written' do
      before { repository.save({ steps: { name: { first_name: 'John' } } }) }

      it 'returns the stored data' do
        expect(repository.read).to eq({ steps: { name: { first_name: 'John' } } })
      end
    end

    context 'when data is returned' do
      before { repository.save({ data: { key: 'value' } }) }

      it 'returns a deep copy, not the original' do
        read_data = repository.read
        read_data[:data][:key] = 'modified'

        expect(repository.read[:data][:key]).to eq('value')
      end
    end
  end

  describe '#write' do
    context 'when repository is empty' do
      it 'adds new data' do
        repository.write({ steps: { name: { first_name: 'Alice' } } })

        expect(repository.read).to eq({ steps: { name: { first_name: 'Alice' } } })
      end
    end

    context 'when data exists' do
      before do
        repository.save(
          {
            steps: { name: { first_name: 'John', last_name: 'Doe' } },
            metadata: { user_id: 123 },
          },
        )
      end

      it 'deep merges new data with existing' do
        repository.write({ steps: { email: { email: 'john@example.com' } } })

        expected = {
          steps: {
            name: { first_name: 'John', last_name: 'Doe' },
            email: { email: 'john@example.com' },
          },
          metadata: { user_id: 123 },
        }
        expect(repository.read).to eq(expected)
      end
    end

    context 'when writing overwrites nested keys' do
      before do
        repository.save({ steps: { name: { first_name: 'John', last_name: 'Doe' } } })
      end

      it 'deep merges, preserving unmodified keys' do
        repository.write({ steps: { name: { first_name: 'Jane' } } })

        expect(repository.read[:steps][:name]).to eq(
          {
            first_name: 'Jane',
            last_name: 'Doe',
          },
        )
      end
    end

    context 'when writing with empty hash' do
      before { repository.save({ data: 'value' }) }

      it 'preserves existing data' do
        repository.write({})

        expect(repository.read).to eq({ data: 'value' })
      end
    end

    it 'returns the merged result' do
      repository.save({ steps: { name: { first_name: 'John' } } })
      result = repository.write({ steps: { email: { email: 'john@example.com' } } })

      expect(result).to include({ steps: hash_including(:name, :email) })
    end
  end

  describe '#save' do
    context 'when repository is empty' do
      it 'stores data' do
        repository.save({ steps: { name: { first_name: 'Bob' } } })

        expect(repository.read).to eq({ steps: { name: { first_name: 'Bob' } } })
      end
    end

    context 'when data exists' do
      before do
        repository.save(
          {
            steps: { name: { first_name: 'John' } },
            metadata: { user_id: 123 },
          },
        )
      end

      it 'replaces all data atomically' do
        repository.save({ steps: { email: { email: 'new@example.com' } } })

        expect(repository.read).to eq({ steps: { email: { email: 'new@example.com' } } })
      end

      it 'does not preserve previous metadata' do
        repository.save({ steps: { email: { email: 'new@example.com' } } })

        expect(repository.read).not_to include({ metadata: { user_id: 123 } })
      end
    end

    context 'when saving empty hash' do
      before { repository.save({ data: 'original' }) }

      it 'clears all data' do
        repository.save({})

        expect(repository.read).to eq({})
      end
    end

    context 'when saving nested structures' do
      it 'preserves deep nesting' do
        complex_data = {
          steps: {
            name: { first_name: 'John', last_name: 'Doe' },
            address: {
              street: '123 Main St',
              city: 'Springfield',
              country: { code: 'US', name: 'United States' },
            },
          },
          metadata: { created_at: Time.now, version: 1 },
        }

        repository.save(complex_data)

        expect(repository.read).to eq(complex_data)
      end
    end

    it 'returns the saved data' do
      data = { steps: { name: { first_name: 'Test' } } }
      result = repository.save(data)

      expect(result).to eq(data)
    end

    it 'saves a deep copy, not a reference' do
      data = { steps: { name: { first_name: 'John' } } }
      repository.save(data)

      data[:steps][:name][:first_name] = 'Jane'

      expect(repository.read[:steps][:name][:first_name]).to eq('John')
    end
  end

  describe '#clear' do
    context 'when repository has data' do
      before do
        repository.save(
          {
            steps: { name: { first_name: 'John' }, email: { email: 'john@example.com' } },
            metadata: { user_id: 123 },
          },
        )
      end

      it 'removes all data' do
        repository.clear

        expect(repository.read).to eq({})
      end

      it 'allows subsequent saves' do
        repository.clear
        repository.save({ steps: { name: { first_name: 'Alice' } } })

        expect(repository.read).to eq({ steps: { name: { first_name: 'Alice' } } })
      end
    end

    context 'when repository is already empty' do
      it 'returns nil without error' do
        expect { repository.clear }.not_to raise_error
        expect(repository.read).to eq({})
      end
    end
  end

  describe 'integration: save, write, and read' do
    it 'handles typical wizard flow' do
      repository.save(
        {
          steps: { name: { first_name: 'John', last_name: 'Doe' } },
          metadata: { user_id: 1, created_at: Time.now },
        },
      )

      repository.write({ steps: { email: { email: 'john@example.com' } } })

      expect(repository.read[:steps]).to include(
        name: { first_name: 'John', last_name: 'Doe' },
        email: { email: 'john@example.com' },
      )

      repository.write({ steps: { review: { confirmed: true } } })

      expect(repository.read[:steps]).to include(
        name: hash_including(first_name: 'John'),
        email: hash_including(email: 'john@example.com'),
        review: { confirmed: true },
      )
      expect(repository.read[:metadata]).to include(user_id: 1)
    end

    it 'allows replacing entire state while preserving workflow' do
      repository.save(
        { steps: { step1: { data: 'v1' }, step2: { data: 'v2' } } },
      )

      expect(repository.read[:steps]).to eq(
        {
          step1: { data: 'v1' },
          step2: { data: 'v2' },
        },
      )

      repository.save({ steps: { step1: { data: 'v1_updated' }, step3: { data: 'v3' } } })

      expect(repository.read[:steps]).to eq(
        {
          step1: { data: 'v1_updated' },
          step3: { data: 'v3' },
        },
      )
    end
  end

  describe 'interface contract' do
    it 'implements read method' do
      expect(repository).to respond_to(:read)
    end

    it 'implements write method' do
      expect(repository).to respond_to(:write)
    end

    it 'implements save method' do
      expect(repository).to respond_to(:save)
    end

    it 'implements clear method' do
      expect(repository).to respond_to(:clear)
    end
  end
end
