# frozen_string_literal: true

module DfE
  module Wizard
    module Repository
      # Session-based repository for wizard state persistence
      #
      # Stores wizard state in Rails session as a **flat hash of attributes**.
      # In Solution 3 architecture, the repository doesn't know about step structure -
      # it simply stores key-value pairs. The wizard handles transforming between
      # flat storage and nested `{ steps: {...} }`.
      #
      # Supports multiple wizard instances via `state_key` parameter.
      #
      # @example Single wizard instance
      #   repo = DfE::Wizard::Repository::Session.new(session: session)
      #   repo.write({ first_name: 'John', email: 'john@example.com' })
      #   repo.read  # => { first_name: 'John', email: 'john@example.com' }
      #
      # @example Multiple wizard instances (with state_key)
      #   repo1 = DfE::Wizard::Repository::Session.new(session: session, state_key: 'app_123')
      #   repo2 = DfE::Wizard::Repository::Session.new(session: session, state_key: 'app_456')
      #   # Each maintains separate flat hash
      #
      # @api public
      class Session
        attr_reader :session, :key, :state_key

        # Initialize session repository
        #
        # @param session [ActionDispatch::Request::Session] Rails session object
        # @param key [Symbol] Session key for wizard data storage (default: :wizard_store)
        # @param state_key [String, nil] Optional key for multiple wizard instances
        # @return [void]
        def initialize(session:, key: :wizard_store, state_key: nil)
          @session = session
          @key = key
          @state_key = state_key
        end

        # Read flat hash from session
        #
        # Returns a flat hash with indifferent access (symbol/string keys work).
        #
        # @return [ActiveSupport::HashWithIndifferentAccess] Flat hash of attributes
        #
        # @example
        #   repo.read  # => { first_name: 'John', email: 'john@example.com' }
        def read
          data = session[key] || {}
          result = state_key ? (data[state_key] || {}) : data
          result.with_indifferent_access
        end

        # Write attributes by merging with existing data
        #
        # New attributes are added, existing attributes are updated.
        # Performs a shallow merge at the top level.
        #
        # @param hash [Hash] Flat hash of attributes to merge
        # @return [void]
        #
        # @example
        #   repo.write({ first_name: 'John', last_name: 'Doe' })
        #   repo.write({ email: 'john@example.com' })  # Merges, doesn't replace
        #   repo.read  # => { first_name: 'John', last_name: 'Doe', email: 'john@example.com' }
        def write(hash)
          normalized = hash.deep_stringify_keys

          if state_key
            current_data = session[key] || {}
            current_state = current_data[state_key] || {}
            session[key] = current_data.merge(state_key => current_state.merge(normalized))
          else
            current = session[key] || {}
            session[key] = current.merge(normalized)
          end
        end

        # Save state atomically by replacing entire data
        #
        # Overwrites all previous data for this wizard instance.
        #
        # @param hash [Hash] Complete flat hash to save
        # @return [void]
        #
        # @example
        #   repo.save({ first_name: 'Alice', email: 'alice@example.com' })
        #   # All previous data is gone, only these attributes remain
        def save(hash)
          normalized = hash.deep_stringify_keys.deep_dup

          if state_key
            current_data = session[key] || {}
            session[key] = current_data.merge(state_key => normalized)
          else
            session[key] = normalized
          end
        end

        # Clear all stored data for this wizard instance
        #
        # @return [void]
        def clear
          if state_key
            current_data = session[key]
            current_data&.delete(state_key)
          else
            session.delete(key)
          end
        end
      end
    end
  end
end
