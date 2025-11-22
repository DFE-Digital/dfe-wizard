RSpec.describe DfE::Wizard::Repository::InMemory do
  subject(:repository) { described_class.new }

  describe '#read' do
    context 'when no data has been written' do
      it 'returns an empty hash' do
        expect(repository.read).to eq({})
      end
    end

    context 'when data has been written' do
      before { repository.write({ first_name: 'John', last_name: 'Doe' }) }

      it 'returns the stored flat hash' do
        expect(repository.read).to eq({ first_name: 'John', last_name: 'Doe' })
      end
    end

    context 'when modifying the returned hash' do
      before { repository.write({ email: 'value@example.com' }) }

      it 'does not affect the stored data (returns a copy)' do
        read_data = repository.read
        read_data[:email] = 'other@example.com'

        # Repository data remains unchanged
        expect(repository.read[:email]).to eq('value@example.com')
      end
    end
  end

  describe '#write' do
    context 'when repository is empty' do
      it 'adds new attributes' do
        repository.write({ first_name: 'Alice', last_name: 'Smith' })
        expect(repository.read).to eq({ first_name: 'Alice', last_name: 'Smith' })
      end
    end

    context 'when data exists' do
      before { repository.write({ first_name: 'John', last_name: 'Doe', age: 30 }) }

      it 'merges new attributes with existing' do
        repository.write({ email: 'john@example.com', city: 'London' })

        expect(repository.read).to eq({
                                        first_name: 'John',
                                        last_name: 'Doe',
                                        age: 30,
                                        email: 'john@example.com',
                                        city: 'London',
                                      })
      end

      it 'updates existing attributes' do
        repository.write({ first_name: 'Jane', email: 'jane@example.com' })

        expect(repository.read).to eq({
                                        first_name: 'Jane', # Updated
                                        last_name: 'Doe',    # Preserved
                                        age: 30,             # Preserved
                                        email: 'jane@example.com', # Added
                                      })
      end
    end

    context 'when writing empty hash' do
      before { repository.write({ data: 'value' }) }

      it 'preserves existing data' do
        repository.write({})
        expect(repository.read).to eq({ data: 'value' })
      end
    end

    it 'returns the merged result' do
      repository.write({ first_name: 'John' })
      result = repository.write({ email: 'john@example.com' })

      expect(result).to eq({ first_name: 'John', email: 'john@example.com' })
    end
  end

  describe '#save' do
    context 'when repository is empty' do
      it 'stores data' do
        repository.save({ first_name: 'Bob', last_name: 'Builder' })
        expect(repository.read).to eq({ first_name: 'Bob', last_name: 'Builder' })
      end
    end

    context 'when data exists' do
      before { repository.write({ first_name: 'John', last_name: 'Doe', age: 30 }) }

      it 'replaces all data atomically' do
        repository.save({ email: 'new@example.com' })

        # Old data is gone
        expect(repository.read).to eq({ email: 'new@example.com' })
      end
    end

    context 'when saving empty hash' do
      before { repository.write({ data: 'original' }) }

      it 'clears all data' do
        repository.save({})
        expect(repository.read).to eq({})
      end
    end

    it 'returns the saved data' do
      data = { first_name: 'Test', last_name: 'User' }
      result = repository.save(data)
      expect(result).to eq(data)
    end

    it 'saves a deep copy, not a reference' do
      data = { first_name: 'John' }
      repository.save(data)
      data[:first_name] = 'Jane'

      expect(repository.read[:first_name]).to eq('John')
    end
  end

  describe '#clear' do
    context 'when repository has data' do
      before { repository.write({ first_name: 'John', email: 'john@example.com' }) }

      it 'removes all data' do
        repository.clear
        expect(repository.read).to eq({})
      end

      it 'allows subsequent writes' do
        repository.clear
        repository.write({ first_name: 'Alice' })
        expect(repository.read).to eq({ first_name: 'Alice' })
      end
    end

    context 'when repository is already empty' do
      it 'returns nil without error' do
        expect { repository.clear }.not_to raise_error
        expect(repository.read).to eq({})
      end
    end
  end

  describe 'integration: typical wizard flow' do
    it 'handles incremental attribute updates' do
      # Step 1: Name
      repository.write({ first_name: 'John', last_name: 'Doe' })

      # Step 2: Contact
      repository.write({ email: 'john@example.com', phone: '555-1234' })

      # Step 3: Address
      repository.write({ city: 'London', postcode: 'SW1A 1AA' })

      expect(repository.read).to eq({
                                      first_name: 'John',
                                      last_name: 'Doe',
                                      email: 'john@example.com',
                                      phone: '555-1234',
                                      city: 'London',
                                      postcode: 'SW1A 1AA',
                                    })
    end

    it 'handles corrections to previous steps' do
      repository.write({ first_name: 'John', last_name: 'Doe', email: 'john@example.com' })

      # User goes back and changes email
      repository.write({ email: 'john.doe@example.com' })

      expect(repository.read).to eq({
                                      first_name: 'John',
                                      last_name: 'Doe',
                                      email: 'john.doe@example.com', # Updated
                                    })
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
