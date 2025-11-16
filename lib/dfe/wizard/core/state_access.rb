module DfE
  module Wizard
    module Core
      # StateAccess: Core read and write operations for wizard state
      #
      # Provides the fundamental interface for accessing and persisting wizard data
      # through the state_store abstraction. All other state modules build on this
      # foundation.
      #
      # This module handles:
      # - Reading raw (unfiltered) state from storage
      # - Writing step data and metadata
      # - Clearing state
      # - Checking for data existence
      #
      # The data is stored and retrieved **without filtering**. For path-aware
      # filtering (hiding unreachable branches), use StateFiltering.
      #
      # @example Basic usage
      #   class MyWizard
      #     include DfE::Wizard::Core::StateAccess
      #
      #     def initialize(state_store)
      #       @state_store = state_store
      #     end
      #   end
      #
      #   wizard.save  # Save current step
      #   wizard.raw_data  # Get all state
      #   wizard.clear_state  # Wipe everything
      #
      # @api public
      module StateAccess
        # Read complete wizard data (all branches, unfiltered)
        #
        # Returns the entire state dictionary from storage including data from
        # all branches (reachable and unreachable). This is the raw, unfiltered view.
        #
        # Use this when you need:
        # - Complete audit trail
        # - Access to all branches regardless of reachability
        # - Debugging or diagnostic information
        #
        # For filtered data (only reachable steps), use {StateFiltering#data}.
        #
        # @return [Hash] All persisted wizard state
        #
        # @example
        #   wizard.raw_data
        #   # => {
        #   #   steps: {
        #   #     name: { first_name: 'John', last_name: 'Doe' },
        #   #     email_uk: { email: 'uk@example.com' },
        #   #     email_non_uk: { email: 'non-uk@example.com' }
        #   #   },
        #   #   metadata: { user_id: 1 }
        #   # }
        #
        # @see StateFiltering#data For filtered view
        # @api public
        def raw_data
          state_store.read
        end

        # Read data for a specific step (unfiltered)
        #
        # Returns step data from storage regardless of whether the step is
        # currently reachable in the wizard path.
        #
        # For path-aware reads, use {StateFiltering#step_data}.
        #
        # @param step_id [Symbol] The step identifier
        # @return [Hash] Step data or empty hash if not found
        #
        # @example Step exists
        #   wizard.raw_step_data(:name)
        #   # => { first_name: 'John', last_name: 'Doe' }
        #
        # @example Step doesn't exist
        #   wizard.raw_step_data(:nonexistent)
        #   # => {}
        #
        # @see StateFiltering#step_data For path-aware reads
        # @api public
        def raw_step_data(step_id)
          raw_data.dig(:steps, step_id) || {}
        end

        # Check if a step has any data (ignoring reachability)
        #
        # Returns true if the step exists in storage with non-empty data,
        # regardless of whether it's in the current wizard path.
        #
        # Useful for diagnostics: "Did the user ever visit this step?"
        #
        # @param step_id [Symbol] The step identifier
        # @return [Boolean] True if step has data
        #
        # @example Step with data
        #   wizard.step_data_exists?(:name)
        #   # => true
        #
        # @example Empty step
        #   wizard.step_data_exists?(:empty_step)
        #   # => false
        #
        # @see StateFiltering#step_data_present? For path-aware check
        # @api public
        def step_data_exists?(step_id)
          raw_step_data(step_id).present?
        end

        # Save current step data to state store
        #
        # Persists the current step's serializable data to storage.
        # Should be called after form submission and validation.
        #
        # Requires:
        # - `current_step` - Step object with `serializable_data` method
        # - `current_step_name` - Symbol identifier for the step
        #
        # @return [void]
        #
        # @example In controller
        #   if wizard.current_step_valid?
        #     wizard.save
        #     redirect_to wizard.next_step_path
        #   end
        #
        # @api public
        def save
          step_data = current_step.serializable_data
          state_store.write_step(current_step_name, step_data)
        end

        # Write arbitrary data to state store (deep merge)
        #
        # Merges provided data into existing state. Use for storing metadata,
        # system flags, or any non-step data.
        #
        # Performs a **deep merge**: new data is merged with existing, not replacing.
        #
        # @param updates [Hash] Data to merge into state
        # @return [void]
        #
        # @example Store metadata
        #   wizard.write_state(user_id: 1, submitted_at: Time.current)
        #
        # @example Store nested data
        #   wizard.write_state(
        #     tracking: {
        #       session_id: 'abc123',
        #       ip_address: '127.0.0.1'
        #     }
        #   )
        #
        # @api public
        def write_state(updates)
          state_store.write(updates)
        end

        # Clear all wizard data from state store
        #
        # **WARNING**: This is destructive and removes all data including
        # unreachable branches. Usually called after wizard completion.
        #
        # Consider using {StateLifecycle#mark_completed} if you want to preserve
        # state for audit/undo purposes.
        #
        # @return [void]
        #
        # @example
        #   wizard.complete!
        #   wizard.clear_state
        #
        # @see StateLifecycle#mark_completed For non-destructive completion
        # @api public
        def clear_state
          state_store.clear
        end
      end
    end
  end
end
