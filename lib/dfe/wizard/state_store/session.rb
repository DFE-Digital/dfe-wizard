module DfE
  module Wizard
    module StateStore
      # Session-based state store for Rails applications
      #
      # Stores wizard state in Rails session with automatic persistence.
      # Supports both single-wizard and multi-wizard (multi-tab) scenarios.
      #
      # Data structure: { steps: { step_id: { field: value, ... }, ... }, ...metadata }
      #
      # @api public
      #
      # @example Single wizard per session
      #   # In controller:
      #   store = Session.new(session, key: :personal_info_wizard)
      #   wizard = PersonalInformationWizard.new(current_step: :name, repository: store)
      #
      # @example Multiple wizards (multi-tab support)
      #   # User opens multiple tabs, each with unique wizard instance
      #   wizard_id = params[:wizard_id] || SecureRandom.uuid
      #   store = Session.new(session, key: :wizards, state_key: wizard_id)
      #   wizard = PersonalInformationWizard.new(current_step: :name, repository: store)
      class Session < Base
        # Initialize with session hash
        #
        # @param session [Hash] Rails session object
        # @param key [Symbol] session key for storing wizard state (default: :wizard_state)
        # @param state_key [String, nil] optional sub-key for multi-instance support
        #
        # @example Single wizard
        #   Session.new(session, key: :personal_info_wizard)
        #   # session structure: { personal_info_wizard: { steps: {...} } }
        #
        # @example Multi-tab wizards
        #   Session.new(session, key: :my_wizard, state_key: 'abc-123')
        #   # session structure: { my_wizard: { 'abc-123': { steps: {...} }, 'xyz-456': {...} } }
        def initialize(session:, key:, state_key: nil)
          @session = session
          @key = key
          @state_key = state_key
        end

        # Read all state from session
        #
        # Returns current wizard state, symbolizing all keys.
        # Handles both Hash and JSON string storage formats.
        #
        # @return [Hash] current state with symbolized keys
        #
        # @example
        #   store.read
        #   # => { steps: { email: { email: 'user@example.com' }, ... }, return_to_review: :email }
        def read
          state = if @state_key
                    @session.dig(@key, @state_key) || {}
                  else
                    @session[@key] || {}
                  end

          state.is_a?(String) ? JSON.parse(state).deep_symbolize_keys : state.deep_symbolize_keys
        end

        # Write updates to session (deep merge)
        #
        # Merges updates into existing state and persists to session.
        # Creates nested structure if using state_key.
        #
        # @param updates [Hash] state updates to merge
        # @return [void]
        #
        # @example
        #   store.write(steps: { email: { email: 'new@example.com' } })
        #   store.write(return_to_review: :email)
        def write(updates)
          current = read
          merged = current.deep_merge(updates)

          if @state_key
            @session[@key] ||= {}
            @session[@key][@state_key] = merged
          else
            @session[@key] = merged
          end
        end

        # Write a single step to session
        #
        # Convenience method that merges step data into steps hash.
        # Preserves data from other steps.
        #
        # @param step_id [Symbol] the step identifier
        # @param data [Hash] the step data
        # @return [void]
        #
        # @example
        #   store.write_step(:email, { email: 'user@example.com', confirmed: true })
        #   # session now contains: { steps: { email: { email: '...', confirmed: true } } }
        def write_step(step_id, data)
          steps = read.dig(:steps) || {}
          write(steps: steps.merge(step_id => data))
        end

        # Get data for a specific step
        #
        # Returns data hash for requested step, or empty hash if not found.
        # Does not raise errors on missing steps.
        #
        # @param step_id [Symbol] the step identifier
        # @return [Hash] the step data (empty hash if not found)
        #
        # @example Step exists
        #   store.step_data(:email)
        #   # => { email: 'user@example.com', confirmed: true }
        #
        # @example Step not found
        #   store.step_data(:missing_step)
        #   # => {}
        def step_data(step_id)
          read.dig(:steps, step_id) || {}
        end

        # Clear all state from session
        #
        # Removes wizard state from session entirely.
        # If using state_key, only clears that specific wizard instance.
        #
        # @return [void]
        #
        # @example Single wizard
        #   store.clear
        #   # session[:wizard_state] is deleted
        #
        # @example Multi-wizard
        #   store.clear
        #   # Only session[:wizards]['abc-123'] is deleted
        def clear
          if @state_key
            @session[@key]&.delete(@state_key)
          else
            @session.delete(@key)
          end
        end
      end
    end
  end
end
