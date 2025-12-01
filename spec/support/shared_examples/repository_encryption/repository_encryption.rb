RSpec.shared_examples 'repository encryption' do
  # Requires:
  # - let(:base_params) { { repository_specific_params } }
  # - build_repository(encrypted: bool, encryptor: encryptor) helper method

  let(:encrypt_key) { 'test-secret-encryption-key-123' }
  let(:encrypt_salt) { 'fixed-salt-for-reproducible-tests' }

  let(:encryptor) do
    key = ActiveSupport::KeyGenerator.new(encrypt_key).generate_key(encrypt_salt, 32)
    ActiveSupport::MessageEncryptor.new(key)
  end

  let(:encrypted_format_regex) do
    /^[A-Za-z0-9\/+=]+--[A-Za-z0-9\/+=]+--[A-Za-z0-9\/+=]+$/
  end

  describe 'write with encryption' do
    context 'when data contains strings' do
      it 'encrypts string values before storage' do
        repository = build_repository(encrypted: true, encryptor:)
        repository.write({ name: 'John', email: 'john@example.com' })

        # Read raw data without decryption to verify encryption happened
        raw_data = repository.read_data

        # Strings should be encrypted (not plaintext)
        expect(raw_data[:name]).not_to eq('John')
        expect(raw_data[:email]).not_to eq('john@example.com')

        # Encrypted format should be valid base64-like with double-dash separator
        # (MessageEncryptor uses: base64(iv)--base64(ciphertext) format)
        expect(raw_data[:name]).to match(encrypted_format_regex)
        expect(raw_data[:email]).to match(encrypted_format_regex)
      end

      it 'decrypts on read transparently' do
        repository = build_repository(encrypted: true, encryptor:)
        repository.write({ name: 'John', email: 'john@example.com' })

        # Read through public interface should decrypt
        data = repository.read
        expect(data[:name]).to eq('John')
        expect(data[:email]).to eq('john@example.com')
      end

      it 'round-trips data correctly through write and read' do
        repository = build_repository(encrypted: true, encryptor:)
        original = { name: 'Alice', email: 'alice@example.com', phone: '555-1234' }
        repository.write(original)

        retrieved = repository.read
        expect(retrieved).to include(original)
      end
    end

    context 'when data contains nil and non-string values' do
      it 'leaves nil values unencrypted' do
        repository = build_repository(encrypted: true, encryptor:)
        repository.write({ name: nil, active: true })

        raw_data = repository.read_data
        expect(raw_data[:name]).to be_nil
      end

      it 'leaves non-string values unencrypted' do
        repository = build_repository(encrypted: true, encryptor:)
        repository.write({ count: 42, active: true, ratio: 3.14 })

        raw_data = repository.read_data
        expect(raw_data.symbolize_keys).to eq(
          count: 42,
          active: true,
          ratio: 3.14,
        )
      end

      it 'round-trips mixed data types' do
        repository = build_repository(encrypted: true, encryptor:)
        original = {
          name: 'Bob',
          age: 30,
          active: true,
          score: 98.5,
          notes: nil,
          description: 'A test user',
        }
        repository.write(original)

        retrieved = repository.read
        expect(retrieved).to include(original)
      end
    end

    context 'when data contains nested hashes' do
      it 'encrypts all nested string values' do
        repository = build_repository(encrypted: true, encryptor:)
        repository.write({
                           user: {
                             name: 'Charlie',
                             contact: {
                               email: 'charlie@example.com',
                               phone: '555-5678',
                             },
                           },
                         })

        raw_data = repository.read_data

        # All string values should be encrypted
        expect(raw_data[:user][:name]).not_to eq('Charlie')
        expect(raw_data[:user][:contact][:email]).not_to eq('charlie@example.com')
        expect(raw_data[:user][:contact][:phone]).not_to eq('555-5678')
      end

      it 'decrypts nested hashes transparently' do
        repository = build_repository(encrypted: true, encryptor:)
        original = {
          user: {
            name: 'Diana',
            contact: {
              email: 'diana@example.com',
              phone: '555-9999',
            },
          },
        }
        repository.write(original)

        retrieved = repository.read
        expect(retrieved).to include(original)
      end
    end

    context 'when data is saved (atomic replace)' do
      it 'encrypts all string values in saved data' do
        repository = build_repository(encrypted: true, encryptor:)
        repository.save({ ssn: '123-45-6789', bank: '9876543210' })

        raw_data = repository.read_data
        expect(raw_data[:ssn]).not_to eq('123-45-6789')
        expect(raw_data[:bank]).not_to eq('9876543210')
      end

      it 'replaces all previous data with encrypted new data' do
        repository = build_repository(encrypted: true, encryptor:)
        repository.save({ name: 'Eve', email: 'eve@example.com' })
        repository.save({ account: 'ACC-123' })

        # Previous data should be gone
        data = repository.read

        # Only new encrypted data remains
        expect(data.symbolize_keys).to eq(account: 'ACC-123')
      end
    end

    context 'when encryption key changes (decryption failure)' do
      it 'raises RuntimeError on read with wrong encryptor' do
        repository = build_repository(encrypted: true, encryptor:)
        repository.write({ ssn: '123-45-6789' })

        # Create a different encryptor with different key
        bad_password = 'different-password'
        bad_key = ActiveSupport::KeyGenerator.new(bad_password).generate_key(encrypt_salt, 32)
        bad_encryptor = ActiveSupport::MessageEncryptor.new(bad_key)

        repository.encryptor = bad_encryptor

        expect {
          repository.read
        }.to raise_error(RuntimeError, /Failed to decrypt value/)
      end
    end
  end

  describe 'write without encryption vs with encryption' do
    it 'unencrypted stores plaintext, encrypted stores ciphertext' do
      data = { name: 'Frank', email: 'frank@example.com' }

      unencrypted_repository.write(data)
      encrypted_repository.write(data)

      unencrypted_raw = unencrypted_repository.read_data
      encrypted_raw = encrypted_repository.read_data

      # Unencrypted should have plaintext
      expect(unencrypted_raw[:name]).to eq('Frank')

      # Encrypted should have ciphertext
      expect(encrypted_raw[:name]).not_to eq('Frank')
      expect(encrypted_raw[:name]).to match(encrypted_format_regex)
    end

    it 'both repositories read as plaintext to consumers' do
      data = { name: 'Grace', email: 'grace@example.com' }

      unencrypted_repository.write(data)
      encrypted_repository.write(data)

      expect(unencrypted_repository.read).to include(data)
      expect(encrypted_repository.read).to include(data)
    end
  end

  describe 'incremental writes with encryption' do
    it 'merges encrypted data on subsequent writes' do
      repository = build_repository(encrypted: true, encryptor:)
      repository.write({ name: 'Henry' })
      repository.write({ email: 'henry@example.com' })
      repository.write({ phone: '555-1111' })

      data = repository.read
      expect(data).to include(
        name: 'Henry',
        email: 'henry@example.com',
        phone: '555-1111',
      )
    end

    it 'preserves existing encrypted values during merge' do
      repository = build_repository(encrypted: true, encryptor:)
      repository.write({ name: 'Ivy', email: 'ivy@example.com' })
      repository.write({ phone: '555-2222' })

      data = repository.read
      expect(data[:name]).to eq('Ivy')
      expect(data[:email]).to eq('ivy@example.com')
      expect(data[:phone]).to eq('555-2222')
    end
  end

  describe 'encryption of sensitive data patterns' do
    it 'encrypts SSN format data' do
      repository = build_repository(encrypted: true, encryptor:)
      repository.write({ ssn: '123-45-6789' })
      raw_data = repository.read_data

      expect(raw_data[:ssn]).not_to eq('123-45-6789')
      expect(repository.read[:ssn]).to eq('123-45-6789')
    end

    it 'encrypts bank account numbers' do
      repository = build_repository(encrypted: true, encryptor:)
      repository.write({ bank_account: '9876543210' })
      raw_data = repository.read_data

      expect(raw_data[:bank_account]).not_to eq('9876543210')
      expect(repository.read[:bank_account]).to eq('9876543210')
    end

    it 'encrypts email addresses' do
      repository = build_repository(encrypted: true, encryptor:)
      repository.write({ email: 'sensitive@example.com' })
      raw_data = repository.read_data

      expect(raw_data[:email]).not_to eq('sensitive@example.com')
      expect(repository.read[:email]).to eq('sensitive@example.com')
    end

    it 'encrypts credit card data' do
      repository = build_repository(encrypted: true, encryptor:)
      repository.write({ cc: '4111111111111111' })
      raw_data = repository.read_data

      expect(raw_data[:cc]).not_to eq('4111111111111111')
      expect(repository.read[:cc]).to eq('4111111111111111')
    end
  end

  describe 'encryption with empty and edge cases' do
    it 'encrypts empty strings' do
      repository = build_repository(encrypted: true, encryptor:)
      repository.write({ name: '' })
      raw_data = repository.read_data

      expect(raw_data[:name]).not_to eq('')
      expect(repository.read[:name]).to eq('')
    end

    it 'encrypts whitespace-only strings' do
      repository = build_repository(encrypted: true, encryptor:)
      repository.write({ name: '   ' })
      raw_data = repository.read_data

      expect(raw_data[:name]).not_to eq('   ')
      expect(repository.read[:name]).to eq('   ')
    end

    it 'encrypts very long strings' do
      repository = build_repository(encrypted: true, encryptor:)
      long_text = 'A' * 10_000
      repository.write({ description: long_text })
      raw_data = repository.read_data

      expect(raw_data[:description]).not_to eq(long_text)
      expect(repository.read[:description]).to eq(long_text)
    end

    it 'encrypts strings with special characters' do
      repository = build_repository(encrypted: true, encryptor:)
      special = "Line1\nLine2\tTabbed\r\n{\"json\": true}"
      repository.write({ content: special })
      raw_data = repository.read_data

      expect(raw_data[:content]).not_to eq(special)
      expect(repository.read[:content]).to eq(special)
    end

    it 'encrypts strings with unicode' do
      repository = build_repository(encrypted: true, encryptor:)
      unicode_text = 'Hello 世界 🌍 مرحبا'
      repository.write({ greeting: unicode_text })
      raw_data = repository.read_data

      expect(raw_data[:greeting]).not_to eq(unicode_text)
      expect(repository.read[:greeting]).to eq(unicode_text)
    end
  end

  describe 'deterministic encryption key behavior' do
    it 'same password and salt always produce same key' do
      # Generate key twice with same inputs
      key1 = ActiveSupport::KeyGenerator.new(encrypt_key).generate_key(encrypt_salt, 32)
      key2 = ActiveSupport::KeyGenerator.new(encrypt_key).generate_key(encrypt_salt, 32)

      expect(key1).to eq(key2)
    end

    it 'different password produces different key' do
      key1 = ActiveSupport::KeyGenerator.new('password1').generate_key(encrypt_salt, 32)
      key2 = ActiveSupport::KeyGenerator.new('password2').generate_key(encrypt_salt, 32)

      expect(key1).not_to eq(key2)
    end

    it 'same data encrypted with same encryption key decrypts to original' do
      repository1 = build_repository(encrypted: true, encryptor:)
      repository1.write({ data: 'secret message' })

      # Create second repository with same key derivation
      same_encryptor = ActiveSupport::MessageEncryptor.new(
        ActiveSupport::KeyGenerator.new(encrypt_key).generate_key(encrypt_salt, 32),
      )
      repository2 = build_repository(encrypted: true, encryptor: same_encryptor)
      repository2.write({ data: 'secret message' })

      # Both should decrypt to same value
      expect(repository1.read[:data]).to eq('secret message')
      expect(repository2.read[:data]).to eq('secret message')
    end
  end
end
