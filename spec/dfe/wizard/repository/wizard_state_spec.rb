RSpec.describe DfE::Wizard::Repository::WizardState do
  let(:repository) { described_class.new(model: wizard_state) }
  let(:wizard_state) { create(:wizard_state) }
  let(:encryption_key) { SecureRandom.random_bytes(32) }
  let(:encryptor) { ActiveSupport::MessageEncryptor.new(encryption_key) }

  describe '#initialize' do
    it 'raises ArgumentError when model is nil' do
      expect {
        described_class.new(model: nil)
      }.to raise_error(ArgumentError, 'model cannot be nil')
    end

    it 'accepts model parameter' do
      expect {
        described_class.new(model: wizard_state)
      }.not_to raise_error
    end

    it 'stores model as reader' do
      expect(repository.model).to eq(wizard_state)
    end

    it 'uses model.encrypted? flag by default' do
      wizard_state.update(encrypted: true)
      repository_with_encryptor = described_class.new(model: wizard_state, encryptor:)
      expect(repository_with_encryptor.encrypted?).to be(true)
    end

    it 'overrides model.encrypted? when encrypted param provided' do
      wizard_state.update(encrypted: true)
      repository_with_override = described_class.new(model: wizard_state, encrypted: false, encryptor:)
      expect(repository_with_override.encrypted?).to be(false)
    end

    it 'defaults to false when model does not respond to encrypted?' do
      default_repository = described_class.new(model: wizard_state)
      expect(default_repository.encrypted?).to be(false)
    end

    it 'raises ArgumentError when encrypted true but no encryptor' do
      expect {
        described_class.new(model: wizard_state, encrypted: true)
      }.to raise_error(ArgumentError, 'encryptor is required when encrypted: true')
    end

    it 'accepts encryptor when encrypted true' do
      expect {
        described_class.new(model: wizard_state, encrypted: true, encryptor:)
      }.not_to raise_error
    end
  end

  describe '#read' do
    it 'returns empty hash when state is nil' do
      wizard_state.update_column(:state, nil)
      expect(repository.read).to eq({})
    end

    it 'returns hash when state is a hash' do
      wizard_state.update(state: { name: 'John' })
      expect(repository.read).to eq({ 'name' => 'John' })
    end

    it 'parses JSON string to hash' do
      wizard_state.update_column(:state, '{"name":"John","age":30}')
      expect(repository.read).to eq({ 'name' => 'John', 'age' => 30 })
    end

    it 'returns empty hash for unexpected types' do
      wizard_state.update_column(:state, 12345)
      expect(repository.read).to eq({})
    end

    it 'raises error for malformed JSON string' do
      wizard_state.update_column(:state, '{"invalid":json}')
      expect {
        repository.read
      }.to raise_error(RuntimeError, /Failed to parse wizard state/)
    end

    context 'with encryption enabled' do
      let(:encrypted_repository) { described_class.new(model: wizard_state, encrypted: true, encryptor:) }

      it 'decrypts data after reading' do
        encrypted_value = encryptor.encrypt_and_sign('John')
        wizard_state.update(state: { name: encrypted_value })
        result = encrypted_repository.read
        expect(result['name']).to eq('John')
      end

      it 'raises error when decryption fails' do
        wizard_state.update(state: { name: 'bad_encrypted_value' })
        expect {
          encrypted_repository.read
        }.to raise_error(/Failed to decrypt value/)
      end
    end
  end

  describe '#write' do
    it 'merges new data into existing state' do
      wizard_state.update(state: { name: 'John' })
      repository.write({ age: 30 })
      wizard_state.reload
      expect(wizard_state.state).to include('name' => 'John', 'age' => 30)
    end

    it 'does nothing when hash is nil' do
      wizard_state.update(state: { original: 'data' })
      repository.write(nil)
      wizard_state.reload
      expect(wizard_state.state).to eq({ 'original' => 'data' })
    end

    it 'does nothing when hash is empty' do
      wizard_state.update(state: { original: 'data' })
      repository.write({})
      wizard_state.reload
      expect(wizard_state.state).to eq({ 'original' => 'data' })
    end

    it 'persists changes to database' do
      wizard_state.update(state: {})
      repository.write({ name: 'Jane' })
      wizard_state.reload
      expect(wizard_state.state).to include('name' => 'Jane')
    end

    context 'with encryption enabled' do
      let(:encrypted_repository) { described_class.new(model: wizard_state, encrypted: true, encryptor:) }

      it 'encrypts data before writing' do
        wizard_state.update(state: {})
        encrypted_repository.write({ name: 'Jane' })
        wizard_state.reload
        stored_value = wizard_state.state['name']
        expect(encryptor.decrypt_and_verify(stored_value)).to eq('Jane')
      end
    end
  end

  describe '#save' do
    it 'replaces entire state' do
      wizard_state.update(state: { old: 'data' })
      repository.save({ email: 'john@example.com' })
      wizard_state.reload
      expect(wizard_state.state).to eq({ 'email' => 'john@example.com' })
    end

    it 'does nothing when hash is nil' do
      wizard_state.update(state: { original: 'data' })
      repository.save(nil)
      wizard_state.reload
      expect(wizard_state.state).to eq({ 'original' => 'data' })
    end

    it 'overwrites existing state completely' do
      wizard_state.update(state: { old: 'data', keep: 'this' })
      repository.save({ new: 'data' })
      wizard_state.reload
      expect(wizard_state.state).to eq({ 'new' => 'data' })
    end

    it 'persists to database' do
      repository.save({ name: 'Alice', age: 25 })
      wizard_state.reload
      expect(wizard_state.state).to eq({ 'name' => 'Alice', 'age' => 25 })
    end

    context 'with encryption enabled' do
      let(:encrypted_repository) { described_class.new(model: wizard_state, encrypted: true, encryptor:) }

      it 'encrypts entire state before saving' do
        encrypted_repository.save({ name: 'Bob', ssn: '123-45-6789' })
        wizard_state.reload
        expect(encryptor.decrypt_and_verify(wizard_state.state['name'])).to eq('Bob')
        expect(encryptor.decrypt_and_verify(wizard_state.state['ssn'])).to eq('123-45-6789')
      end
    end
  end

  describe '#clear' do
    it 'destroys the model record' do
      record_id = wizard_state.id
      repository.clear
      expect(WizardState.find_by(id: record_id)).to be_nil
    end
  end

  describe '#readable_attributes' do
    it 'returns only state column' do
      expect(repository.readable_attributes).to eq([:state])
    end
  end

  describe '#writable_attributes' do
    it 'returns only state column' do
      expect(repository.writable_attributes).to eq([:state])
    end
  end

  describe '#encrypted?' do
    it 'returns false by default' do
      default_wizard_state = create(:wizard_state, encrypted: false)
      default_repository = described_class.new(model: default_wizard_state)
      expect(default_repository.encrypted?).to be(false)
    end

    it 'returns true when encryption enabled' do
      encrypted_wizard_state = create(:wizard_state, encrypted: true)
      encrypted_repository = described_class.new(model: encrypted_wizard_state, encryptor:)
      expect(encrypted_repository.encrypted?).to be(true)
    end
  end

  describe 'complete workflow' do
    it 'writes, reads, and updates state' do
      repository.write({ name: 'John' })
      wizard_state.reload
      expect(repository.read).to include('name' => 'John')

      repository.write({ email: 'john@example.com' })
      wizard_state.reload
      expect(repository.read).to include('name' => 'John', 'email' => 'john@example.com')
    end

    it 'saves and replaces entire state' do
      repository.write({ name: 'John', age: 30 })
      wizard_state.reload

      repository.save({ name: 'Jane' })
      wizard_state.reload

      expect(repository.read).to eq({ 'name' => 'Jane' })
    end

    it 'handles multiple records independently' do
      first_wizard_state = create(:wizard_state, state: {})
      second_wizard_state = create(:wizard_state, state: {})

      first_repository = described_class.new(model: first_wizard_state)
      second_repository = described_class.new(model: second_wizard_state)

      first_repository.write({ name: 'Record1' })
      second_repository.write({ name: 'Record2' })

      expect(first_repository.read).to include('name' => 'Record1')
      expect(second_repository.read).to include('name' => 'Record2')
    end
  end

  describe 'with encryption workflow' do
    it 'encrypts sensitive data and reads it back' do
      encrypted_wizard_state = create(:wizard_state, encrypted: true)
      encrypted_repository = described_class.new(model: encrypted_wizard_state, encryptor:)

      encrypted_repository.write({ ssn: '123-45-6789', name: 'John' })
      encrypted_wizard_state.reload

      state = encrypted_repository.read
      expect(state['ssn']).to eq('123-45-6789')
      expect(state['name']).to eq('John')
    end

    it 'stores encrypted values in database' do
      encrypted_wizard_state = create(:wizard_state, encrypted: true)
      encrypted_repository = described_class.new(model: encrypted_wizard_state, encryptor:)

      encrypted_repository.write({ ssn: '123-45-6789' })
      encrypted_wizard_state.reload

      stored_ssn = encrypted_wizard_state.state['ssn']
      expect(encryptor.decrypt_and_verify(stored_ssn)).to eq('123-45-6789')
    end

    it 'preserves encryption across save' do
      encrypted_wizard_state = create(:wizard_state, encrypted: true)
      encrypted_repository = described_class.new(model: encrypted_wizard_state, encryptor:)

      encrypted_repository.save({ ssn: '999-88-7777', name: 'Alice' })
      encrypted_wizard_state.reload

      expect(encryptor.decrypt_and_verify(encrypted_wizard_state.state['ssn'])).to eq('999-88-7777')
      expect(encryptor.decrypt_and_verify(encrypted_wizard_state.state['name'])).to eq('Alice')
    end
  end

  describe 'error handling' do
    it 'raises error for invalid JSON' do
      wizard_state.update_column(:state, 'not valid json')
      expect {
        repository.read
      }.to raise_error(RuntimeError, /Failed to parse wizard state/)
    end
  end
end
