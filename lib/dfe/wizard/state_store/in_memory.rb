# frozen_string_literal: true

module DfE
  module Wizard
    module StateStore
      # In-memory state store for testing and development
      #
      # Stores all wizard state in a Hash in memory. Useful for tests and development.
      # Data structure: { steps: { step_id: { field: value, ... }, ... }, ...metadata }
      #
      # @api public
      class InMemory < Base
        # Initialize with optional initial state
        #
        # @param initial_state [Hash] optional starting state (deep copied)
        #
        # @example
        #   store = InMemory.new(steps: { email: { email: 'test@example.com' } })
        def initialize(initial_state = {})
          @data = initial_state.deep_dup
          @state_key = SecureRandom.uuid
        end

        # Read all state from memory
        #
        # @return [Hash] current state (duplicated)
        #
        # @example
        #   store.read  # => { steps: { ... }, ...metadata }
        def read
          @data.dup
        end

        # Write updates to memory (deep merge)
        #
        # @param updates [Hash] state updates to merge
        # @return [void]
        #
        # @example
        #   store.write(steps: { email: { email: 'new@example.com' } })
        def write(updates)
          @data = @data.deep_merge(updates)
        end

        # Write a single step to memory
        #
        # Convenience method that merges step data into steps hash
        #
        # @param step_id [Symbol] the step identifier
        # @param data [Hash] the step data
        # @return [void]
        #
        # @example
        #   store.write_step(:email, { email: 'user@example.com' })
        def write_step(step_id, data)
          steps = @data[:steps] || {}
          write(steps: steps.merge(step_id => data))
        end

        # Get data for a specific step
        #
        # @param step_id [Symbol] the step identifier
        # @return [Hash] the step data (empty hash if not found)
        #
        # @example
        #   store.step_data(:email)  # => { email: 'user@example.com' }
        #   store.step_data(:missing)  # => {}
        def step_data(step_id)
          read.dig(:steps, step_id) || {}
        end

        # Clear all state from memory
        #
        # @return [void]
        #
        # @example
        #   store.clear
        def clear
          @data = {}
        end

        # Get unique state key
        #
        # Returns a UUID that identifies this store instance.
        # Useful for tracking state across requests or for session keys.
        #
        # @return [String] unique identifier
        #
        # @example
        #   store.state_key  # => "550e8400-e29b-41d4-a716-446655440000"
        attr_reader :state_key
      end
    end
  end
end
