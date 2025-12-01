module DfE
  module Wizard
    module Repository
      # In-memory repository for wizard state persistence
      #
      # Stores all wizard state in a simple hash. Suitable for testing, development,
      # or non-persistent use cases. Data is lost when the instance is garbage collected.
      #
      # Implements the Repository interface:
      # - `read` → Returns complete state hash (deep copy)
      # - `write(hash)` → Deep merges data into state
      # - `save(hash)` → Replaces entire state atomically
      # - `clear` → Wipes all data
      #
      # @example Basic usage
      #   repo = DfE::Wizard::Repository::InMemory.new
      #   repo.save({ steps: { name: { first_name: 'John' } } })
      #   repo.read[:steps]  # => { name: { first_name: 'John' } }
      #
      # @example With StateStore
      #   repo = DfE::Wizard::Repository::InMemory.new
      #   state_store = DfE::Wizard::StateStore::Base.new(
      #     repository: repo,
      #     current_step_params: { email: 'test@example.com' }
      #   )
      #
      # @api public
      class InMemory < Base
        # Initialize empty in-memory store
        #
        # @return [void]
        def initialize(encrypted: false, encryptor: nil)
          @data = {}

          super
        end

        # Read complete wizard state from memory
        #
        # Returns a deep copy to prevent accidental mutations of internal state.
        #
        # @return [Hash] Complete wizard state (empty hash if never written)
        #
        # @example
        #   repo.read_data  # => { steps: { name: { first_name: 'John' } } }
        def read_data
          @data.deep_dup
        end

        # Write state by deep merging with existing data
        #
        # New keys are added, existing keys are updated with a deep merge.
        # Useful for incremental, per-step updates.
        #
        # @param hash [Hash] Data to merge into state
        # @return [Hash] The merged result
        #
        # @example Add a step without affecting others
        #   repo.save({ steps: { name: { first_name: 'John' } } })
        #   repo.write({ steps: { email: { email: 'john@example.com' } } })
        #   repo.read[:steps]
        #   # => { name: { first_name: 'John' }, email: { email: 'john@example.com' } }
        def write_data(hash)
          @data.deep_merge!(hash)
        end

        # Save state atomically by replacing entire data
        #
        # Overwrites all previous data. Use when you have a complete snapshot
        # or want to replace state entirely (e.g., during testing setup).
        #
        # @param hash [Hash] Complete state to save
        # @return [Hash] The saved data
        #
        # @example Replace entire wizard state
        #   repo.save({
        #     steps: {
        #       name: { first_name: 'Jane', last_name: 'Doe' },
        #       email: { email: 'jane@example.com' }
        #     },
        #     completed: true
        #   })
        def save(hash)
          encrypted_data = encrypted? ? encrypt_hash(hash) : hash

          @data = encrypted_data.deep_dup
        end

        # Execute operation in repository context
        #
        # @param operation_class [Class] Operation to instantiate
        # @param step [Object] Step instance
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
        #   repo.clear
        #   repo.read  # => {}
        def clear
          @data = {}
        end
      end
    end
  end
end
