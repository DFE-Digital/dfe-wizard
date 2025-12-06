module DfE
  module Wizard
    module Repository
      # Repository for persisting wizard state to a model with JSONB/JSON column
      #
      # This repository assumes a model with:
      # - state (JSONB/JSON column) - stores wizard state as JSON
      # - key (string column) - identifies the wizard type
      # - state_key (string column, optional) - optional scoping key
      # - encrypted (boolean column, optional) - flag to enable encryption per-record
      #
      # Database compatibility:
      # - PostgreSQL: Uses native JSONB type (strongly typed, indexable, queryable)
      # - MySQL: Uses native JSON type (loose validation, indexable)
      # - SQLite: Uses TEXT with JSON validation (via CHECK constraint)
      # - Others (MariaDB, Oracle): Typically JSON type or TEXT with custom handling
      #
      # The gem does NOT create the model or migrations. Developers should:
      # 1. Create the model with appropriate columns
      # 2. Define migrations with correct column types for their database
      # 3. Pass the model instance to this repository
      #
      # @example PostgreSQL with JSONB
      #   # Migration:
      #   create_table :wizard_states do |t|
      #     t.jsonb :state, default: {}, null: false
      #     t.string :key, null: false
      #     t.string :state_key
      #     t.boolean :encrypted, default: false
      #     t.timestamps
      #   end
      #
      # @example MySQL with JSON
      #   # Migration:
      #   create_table :wizard_states do |t|
      #     t.json :state, default: proc { "JSON_OBJECT()" }, null: false
      #     t.string :key, null: false
      #     t.string :state_key
      #     t.boolean :encrypted, default: false
      #     t.timestamps
      #   end
      #
      # @example SQLite with TEXT
      #   # Migration:
      #   create_table :wizard_states do |t|
      #     t.text :state, default: "{}", null: false
      #     t.string :key, null: false
      #     t.string :state_key
      #     t.boolean :encrypted, default: false
      #     t.timestamps
      #   end
      #
      # @example Usage
      #   model = WizardState.find_by(key: :my_wizard, state_key: session_id)
      #   repository = Repository::WizardState.new(model:)
      #   repository.read # => { name: "John", email: "john@example.com" }
      #
      # @example With encryption
      #   # When model.encrypted? is true, data is automatically encrypted
      #   repository = Repository::WizardState.new(
      #     model:,
      #     encryptor: Rails.application.message_verifier('my-secret')
      #   )
      #   repository.write({ name: "Jane" })
      #
      # @api public
      class WizardState < Base
        attr_reader :model

        # Initialize repository backed by a model
        #
        # @param model [Object] ActiveRecord model instance with state column
        # @param encrypted [Boolean] Override model.encrypted? (default: false)
        # @param encryptor [Object, nil] Encryptor instance for encryption/decryption
        #
        # @return [void]
        # @raise [ArgumentError] If model is nil or encrypted but no encryptor provided
        # @raise [NoMethodError] If model doesn't respond to state column methods
        #
        # @example With default encrypted flag from model
        #   repository = WizardState.new(model: my_state_record)
        #
        # @example Override encryption
        #   repository = WizardState.new(
        #     model: my_state_record,
        #     encrypted: true,
        #     encryptor: Rails.application.message_verifier('secret')
        #   )
        def initialize(model:, encrypted: nil, encryptor: nil)
          raise ArgumentError, 'model cannot be nil' if model.nil?

          @model = model

          # Use model.encrypted? if available, otherwise default to false
          effective_encrypted = encrypted.nil? ? model_encrypted_flag : encrypted
          super(encrypted: effective_encrypted, encryptor:)
        end

        # Check if encryption is enabled for this record
        #
        # First checks explicit encrypted parameter, then falls back to model.encrypted?
        # if available, then defaults to false.
        #
        # @return [Boolean] True if encryption should be used
        def encrypted?
          @encrypted
        end

        # Readable columns for this record
        #
        # By default, returns state column only. Override in subclass to expose
        # additional columns (e.g., key, state_key, encrypted flag).
        #
        # @return [Array<Symbol>] Readable column names
        def readable_attributes
          [:state]
        end

        # Writable columns for this record
        #
        # By default, only state column is writable. Override in subclass to allow
        # modifications to key, state_key, or encrypted flag.
        #
        # @return [Array<Symbol>] Writable column names
        def writable_attributes
          [:state]
        end

        private

        # Get the encrypted flag from the model
        #
        # Attempts to call model.encrypted? if available, otherwise returns false.
        #
        # @return [Boolean] Value of model.encrypted? or false if not available
        def model_encrypted_flag
          return false unless @model.respond_to?(:encrypted?)

          @model.encrypted? == true
        end

        # Read raw state data from the model
        #
        # Retrieves the state column from the model and ensures it's a Hash.
        # Handles both:
        # - JSONB/JSON: Already a Hash after deserialization
        # - TEXT: May be JSON string requiring parsing
        #
        # @return [Hash] State data (empty hash if state is nil)
        # @raise [JSON::ParserError] If state is a malformed JSON string
        def read_data
          state = @model.state

          case state
          when Hash
            # Already deserialized (JSONB/JSON types)
            state
          when String
            # Serialized JSON (TEXT column or edge case)
            JSON.parse(state)
          else
            # Unexpected type - coerce to empty hash
            {}
          end
        rescue JSON::ParserError => e
          raise "Failed to parse wizard state from model: #{e.message}"
        end

        # Write raw state data to the model
        #
        # Assigns the state hash to the model and persists via save!
        #
        # For JSONB/JSON types:
        # - The database driver handles serialization to JSON
        # - No explicit JSON.dump required
        #
        # For TEXT columns:
        # - Consider using a before_save callback on the model to convert Hash → JSON
        # - Or store as-is and handle in read_data
        #
        # @param hash [Hash] Complete state to persist
        # @return [void]
        # @raise [ActiveRecord::RecordInvalid] If model validation fails
        # @raise [ActiveRecord::StatementInvalid] If database error occurs
        def write_data(hash)
          # Ensure hash is serializable
          validate_serializable!(hash)

          # Assign and persist
          @model.state = hash
          @model.save!
        end

        # Delete all data from storage
        #
        # Destroys the model record entirely. This is a destructive operation.
        # Override if you need different behavior (e.g., just clear the state column).
        #
        # @return [void]
        # @raise [ActiveRecord::RecordNotFound] If record no longer exists
        # @raise [ActiveRecord::DeleteRestrictionError] If foreign keys prevent deletion
        def delete_data
          @model.destroy!
        end

        # Merge new data with existing data
        #
        # Performs standard hash merge: new data takes precedence.
        # Override in subclass for custom merge behavior (e.g., deep merge).
        #
        # @param existing [Hash] Current state
        # @param new_data [Hash] New data to merge in
        # @return [Hash] Merged result
        def merge_data(existing, new_data)
          existing.merge(new_data)
        end

        # Validate that hash is JSON-serializable
        #
        # Checks that all values can be safely converted to JSON.
        # Raises error if unsupported types are found.
        #
        # @param hash [Hash] Data to validate
        # @return [void]
        # @raise [ArgumentError] If hash contains non-serializable types
        def validate_serializable!(hash)
          # Test by attempting JSON round-trip
          JSON.parse(JSON.dump(hash))
        rescue JSON::GeneratorError => e
          raise ArgumentError, "Wizard state contains non-JSON-serializable data: #{e.message}"
        end
      end
    end
  end
end
