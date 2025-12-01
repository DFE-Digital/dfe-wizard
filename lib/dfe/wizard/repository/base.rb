module DfE
  module Wizard
    module Repository
      # Base class for all repository types
      #
      # Provides common encryption/decryption logic and shared method interfaces.
      # All repository implementations should inherit from this class.
      #
      # Subclasses MUST implement:
      # - read_data → Returns raw data from storage
      # - write_data(hash) → Writes raw data to storage
      # - delete_data → Removes data from storage
      #
      # Subclasses MAY override:
      # - encrypted? → Boolean to enable/disable encryption
      # - encryptor → Encryptor instance (REQUIRED if encrypted? is true)
      #
      # @api public
      class Base
        attr_accessor :encrypted
        attr_writer :encryptor

        # Initialize repository with encryption support
        #
        # @param encrypted [Boolean] Enable encryption (default: false)
        # @param encryptor [Object, nil] Encryptor instance (required if encrypted: true)
        # @return [void]
        # @raise [ArgumentError] if encrypted: true but no encryptor provided
        def initialize(encrypted: false, encryptor: nil)
          @encrypted = encrypted
          @encryptor = encryptor

          if (@encrypted.present? && @encryptor.nil?) || !respond_to?(:encryptor)
            raise ArgumentError, 'encryptor is required when encrypted: true'
          end
        end

        # Read complete wizard state
        #
        # Returns data with encryption support. Subclass's read_data method
        # is called to fetch raw data, then decrypted if encryption enabled.
        #
        # @return [Hash] Complete wizard state (empty hash if never written)
        # @raise [RuntimeError] if decryption fails
        #
        # @example
        #   repository.read # => { name: 'John', email: 'john@example.com' }
        def read
          data = read_data
          encrypted? ? decrypt_hash(data) : data
        end

        # Write state by merging with existing data
        #
        # New keys are added, existing keys are updated.
        # Useful for incremental, per-step updates.
        # Data is encrypted if encryption is enabled.
        #
        # @param hash [Hash] Data to merge into state
        # @return [void]
        #
        # @example
        #   repository.write({ name: 'John' })
        #   repository.write({ email: 'john@example.com' })
        #   repository.read # => { name: 'John', email: 'john@example.com' }
        def write(hash)
          return if hash.nil? || hash.empty?

          data = read_data
          data_to_merge = transform_for_write(hash)
          encrypted_data = encrypted? ? encrypt_hash(data_to_merge) : data_to_merge
          merged = merge_data(data, encrypted_data)
          write_data(merged)
        end

        # Save state atomically by replacing entire data
        #
        # Overwrites all previous data. Use when you have a complete snapshot
        # or want to replace state entirely (e.g., during testing setup).
        # Data is encrypted if encryption is enabled.
        #
        # @param hash [Hash] Complete state to save
        # @return [void]
        #
        # @example Replace entire wizard state
        #   repository.save({ name: 'Jane', email: 'jane@example.com' })
        def save(hash)
          return if hash.nil?

          data_to_save = transform_for_write(hash)
          encrypted_data = encrypted? ? encrypt_hash(data_to_save) : data_to_save
          write_data(encrypted_data)
        end

        # Execute operation in repository context
        #
        # Instantiates the operation class with this repository and the step,
        # then calls its `execute` method.
        #
        # @param operation_class [Class] Operation to instantiate and execute
        # @param step [Object] Step instance containing data to operate on
        # @return [Hash] Operation result
        def execute_operation(operation_class:, step:)
          operation_class.new(repository: self, step:).execute
        end

        # Clear all stored data
        #
        # Removes everything from the repository. Useful for starting fresh
        # or cleaning up after a wizard is completed.
        #
        # @return [void]
        #
        # @example
        #   repository.clear
        #   repository.read # => {}
        def clear
          delete_data
        end

        # Read raw data from storage (subclass responsibility)
        #
        # Subclasses MUST implement this to fetch raw data from their storage.
        #
        # @return [Hash] Raw data from storage
        # @raise [NotImplementedError] if not implemented by subclass
        def read_data
          raise NotImplementedError, "#{self.class}#read_data not implemented"
        end

        # Write raw data to storage (subclass responsibility)
        #
        # Subclasses MUST implement this to persist raw data to their storage.
        #
        # @param hash [Hash] Raw data to write to storage
        # @return [void]
        # @raise [NotImplementedError] if not implemented by subclass
        def write_data(hash)
          raise NotImplementedError, "#{self.class}#write_data not implemented"
        end

        # Delete data from storage (subclass responsibility)
        #
        # Subclasses MUST implement this to remove data from their storage.
        #
        # @return [void]
        # @raise [NotImplementedError] if not implemented by subclass
        def delete_data
          raise NotImplementedError, "#{self.class}#delete_data not implemented"
        end

        # Merge new data with existing data (hook for subclasses)
        #
        # Override in subclasses for custom merge behavior.
        # Default: simple hash merge.
        #
        # @param existing [Hash] Existing data
        # @param new_data [Hash] New data to merge
        # @return [Hash] Merged result
        def merge_data(existing, new_data)
          existing.merge(new_data)
        end

        # Transform data for writing (hook for subclasses)
        #
        # Override in subclasses to customize data transformation before write.
        # Default: return data as-is.
        #
        # @param data [Hash] Data to transform
        # @return [Hash] Transformed data
        def transform_for_write(data)
          data
        end

        # Transform data for reading (hook for subclasses)
        #
        # Override in subclasses to customize data transformation after read.
        # Default: return data as-is.
        #
        # @param data [Hash] Data to transform
        # @return [Hash] Transformed data
        def transform_for_read(data)
          data
        end

        # Check if encryption is enabled
        #
        # Override this in subclasses to customize encryption behavior.
        #
        # @return [Boolean]
        def encrypted?
          @encrypted
        end

        # Get encryptor instance
        #
        # Override this in subclasses to provide custom encryptor.
        # REQUIRED if encrypted? returns true.
        #
        # @return [Object] Encryptor responding to encrypt_and_sign/decrypt_and_verify
        # @raise [NotImplementedError] if encrypted? is true but encryptor not provided
        def encryptor
          @encryptor || raise(NotImplementedError, 'encryptor must be provided when encrypted? is true')
        end

        # Encrypt hash to encrypted values
        #
        # @param hash [Hash] Data to encrypt
        # @return [Hash] Hash with encrypted values
        def encrypt_hash(hash)
          hash.deep_transform_values { |value| encrypt_value(value) }
        end

        # Decrypt hash from encrypted values
        #
        # @param hash [Hash] Hash with encrypted values
        # @return [Hash] Hash with decrypted values
        # @raise [RuntimeError] if decryption fails
        def decrypt_hash(hash)
          hash.deep_transform_values { |value| decrypt_value(value) }
        end

        # Encrypt single value
        #
        # @param value [Object] Value to encrypt
        # @return [String] Encrypted value (or original if not a string)
        def encrypt_value(value)
          return value if value.nil? || !value.is_a?(String)

          encryptor.encrypt_and_sign(value)
        end

        # Decrypt single value
        #
        # @param value [Object] Value to decrypt
        # @return [Object] Decrypted value (or original if not a string)
        # @raise [RuntimeError] if decryption fails
        def decrypt_value(value)
          return value unless value.is_a?(String)

          begin
            encryptor.decrypt_and_verify(value)
          rescue StandardError => e
            raise "Failed to decrypt value: #{e.message}"
          end
        end
      end
    end
  end
end
