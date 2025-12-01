module DfE
  module Wizard
    module Repository
      # Session-based repository for wizard state persistence.
      #
      # Stores wizard state in Rails session as a **flat hash of attributes**.
      # In Solution 3 architecture, the repository doesn't know about step structure —
      # it simply stores key-value pairs. The wizard handles transforming between
      # flat storage and nested `{ steps: {...} }`.
      #
      # All session data is automatically converted to `HashWithIndifferentAccess`,
      # allowing seamless access with both symbol and string keys.
      #
      # Supports multiple wizard instances via `state_key` parameter.
      # Supports optional encryption for sensitive session data.
      #
      # @attr_reader [Hash] session
      #   The Rails session hash to use for storage (typically `request.session`).
      # @attr_reader [Symbol, String] key
      #   The session key under which to store wizard data (default: :wizard_store).
      # @attr_reader [String, nil] state_key
      #   Optional: a nested key for multi-wizard scenarios.
      #
      # @example Single wizard instance
      #   repository = DfE::Wizard::Repository::Session.new(session: session)
      #   repository.write({ first_name: 'John', email: 'john@example.com' })
      #   repository.read  # => { first_name: 'John', email: 'john@example.com' }
      #
      # @example Multiple wizard instances (with state_key)
      #   repository_one = DfE::Wizard::Repository::Session.new(session: session, state_key: 'app_123')
      #   repository_two = DfE::Wizard::Repository::Session.new(session: session, state_key: 'app_456')
      #   # Each maintains separate flat hash
      #
      # @example With encryption
      #   repository = DfE::Wizard::Repository::Session.new(
      #     session: session,
      #     encrypted: true,
      #     encryptor: MyEncryptor.new(secret)
      #   )
      #   repository.write({ ssn: '123-45-6789' })  # Encrypted in session
      #   repository.read  # => { ssn: '123-45-6789' } (decrypted)
      #
      # @api public
      class Session < Base
        attr_reader :session, :key, :state_key

        # Initialize with session and optional configuration.
        #
        # @param session [Hash] Rails session hash (typically `ActionDispatch::Request#session`).
        # @param key [Symbol, String] Session key for storing wizard data (default: :wizard_store).
        # @param state_key [String, nil] Optional nested key for multi-wizard support.
        # @param encrypted [Boolean] Enable encryption for sensitive data (default: false).
        # @param encryptor [Object, nil] Encryptor instance (required if encrypted: true).
        #
        # @raise [ArgumentError] if session is nil or encrypted: true without encryptor.
        #
        # @example Single wizard
        #   repository = DfE::Wizard::Repository::Session.new(session: request.session)
        #
        # @example Custom key and encryption
        #   repository = DfE::Wizard::Repository::Session.new(
        #     session: request.session,
        #     key: :my_wizard,
        #     state_key: current_user.id,
        #     encrypted: true,
        #     encryptor: encryptor
        #   )
        def initialize(session:, key: :wizard_store, state_key: nil, encrypted: false, encryptor: nil)
          raise ArgumentError, 'session cannot be nil' if session.nil?

          @session = session
          @key = key
          @state_key = state_key

          super(encrypted:, encryptor:)
        end

        # @api private
        # Get session data container with indifferent access.
        #
        # Ensures all session data is `HashWithIndifferentAccess`, allowing both
        # symbol and string key access throughout.
        #
        # @return [ActiveSupport::HashWithIndifferentAccess] Session data.
        def session_data
          (@session[@key] || {}).with_indifferent_access
        end

        # @api private
        # Get state data for this repository's state_key.
        #
        # For multi-wizard scenarios, extracts nested state. For single wizard,
        # returns the full session data.
        #
        # @param data [Hash] Session data container.
        # @return [ActiveSupport::HashWithIndifferentAccess] State data with indifferent access.
        def state_data(data)
          (@state_key ? (data[@state_key] || {}) : data).with_indifferent_access
        end

        # @api private
        # Read raw (possibly encrypted) data from session.
        #
        # For flat keys: returns entire session[@key].
        # For state_key: returns nested session[@key][@state_key].
        # All data is returned with indifferent access.
        #
        # @return [Hash] Raw session data (symbol/string keys both accessible).
        def read_data
          data = session_data
          @state_key ? state_data(data) : data
        end

        # @api private
        # Write raw (already-encrypted if needed) data to session.
        #
        # For flat keys: merges data into session[@key].
        # For state_key: merges data into session[@key][@state_key].
        # Preserves indifferent access throughout.
        #
        # @param hash [Hash] Data to persist to session.
        # @return [void]
        def write_data(hash)
          data = session_data

          if @state_key
            current_state = state_data(data)
            current_state.merge!(hash)
            data[@state_key] = current_state
          else
            data.merge!(hash)
          end

          @session[@key] = data
        end

        # @api public
        # Save state atomically by replacing entire data.
        #
        # Overwrites all previous data. Use when you have a complete snapshot
        # or want to replace state entirely (e.g., during testing setup).
        # Data is encrypted if encryption is enabled.
        #
        # For flat keys: replaces session[@key] entirely.
        # For state_key: replaces only session[@key][@state_key], preserving other states.
        #
        # @param hash [Hash] Complete state to save.
        # @return [void]
        #
        # @example Replace entire wizard state
        #   repository.save({ name: 'Jane', email: 'jane@example.com' })
        #
        # @example Replace with state_key (multi-wizard)
        #   repository = DfE::Wizard::Repository::Session.new(
        #     session: session,
        #     state_key: 'wizard_1'
        #   )
        #   repository.save({ step: 2, data: 'value' })
        #   # Other states under different state_keys are preserved
        def save(hash)
          return if hash.nil?

          data_to_save = transform_for_write(hash)
          encrypted_data = encrypted? ? encrypt_hash(data_to_save) : data_to_save
          data = session_data

          if @state_key
            data[@state_key] = encrypted_data
          else
            data = encrypted_data
          end

          @session[@key] = data
        end

        # @api private
        # Remove wizard state from session.
        #
        # For flat keys: deletes session[@key] entirely.
        # For state_key: deletes only session[@key][@state_key], preserving other states.
        #
        # @return [void]
        def delete_data
          if @state_key
            data = session_data
            data.delete(@state_key)
            @session[@key] = data if data.any?
          else
            @session.delete(@key)
          end
        end

        # @api public
        # Read complete wizard state with decryption and transformation.
        #
        # Returns data with:
        # 1. Transform applied (via `transform_for_read`)
        # 2. Decryption applied (if encryption enabled)
        # 3. Indifferent access (both symbol and string keys work)
        #
        # @return [ActiveSupport::HashWithIndifferentAccess] Wizard state.
        # @raise [RuntimeError] if decryption fails.
        #
        # @example
        #   repository.write({ first_name: 'Jane' })
        #   data = repository.read
        #   # => <HashWithIndifferentAccess { 'first_name' => 'Jane' }>
        #   # Access both ways:
        #   data[:first_name]      # => 'Jane'
        #   data['first_name']     # => 'Jane'
        #
        # @example With multi-wizard
        #   repository1 = DfE::Wizard::Repository::Session.new(session: session, state_key: 'w1')
        #   repository2 = DfE::Wizard::Repository::Session.new(session: session, state_key: 'w2')
        #   repository1.write({ name: 'Alice' })
        #   repository2.write({ name: 'Bob' })
        #   repository1.read  # => { name: 'Alice' }
        #   repository2.read  # => { name: 'Bob' }
        def read
          data = read_data
          result = transform_for_read(data)
          decrypted = encrypted? ? decrypt_hash(result) : result
          decrypted.with_indifferent_access
        end

        # @api public
        # Prepare data for writing (stringify keys for session storage).
        #
        # Rails sessions serialize/deserialize data, and string keys are the
        # safest format for this. Converts all symbol keys to strings.
        #
        # @param data [Hash] Data to prepare.
        # @return [Hash] Same structure with string keys.
        def transform_for_write(data)
          data.deep_stringify_keys
        end
      end
    end
  end
end
