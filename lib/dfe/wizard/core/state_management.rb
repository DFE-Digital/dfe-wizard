module DfE
  module Wizard
    module Core
      module StateManagement
        # Read complete wizard data (unfiltered, all branches)
        #
        # @return [Hash] All persisted state
        #
        # @example
        #   wizard.raw_data
        #   # => {
        #   #   steps: {
        #   #     name: { first_name: 'John' },
        #   #     email_uk: { email: 'uk@example.com' },
        #   #     email_non_uk: { email: 'non-uk@example.com' }
        #   #   }
        #   # }
        #
        # @api public
        def raw_data
          state_store.read.tap do |read_data|
            log_state_read(data: read_data)
          end
        end

        # Read data for specific step (unfiltered)
        #
        # Returns step data regardless of current flow.
        # Useful for diagnostics and unreachable branches.
        #
        # @param step_id [Symbol] Step identifier
        # @return [Hash] Step data or empty hash
        #
        # @api public
        def raw_step_data(step_id)
          raw_data.dig(:steps, step_id) || {}
        end

        # Check if step has any data (ignoring flow)
        #
        # "Did user ever touch this step?" (even if unreachable now)
        #
        # @param step_id [Symbol] Step identifier
        # @return [Boolean] true if step has data
        #
        # @api public
        def step_data_exists?(step_id)
          raw_step_data(step_id).present?
        end

        # Get all data from unreachable branches
        #
        # Returns steps with data but not in current flow path.
        # Used for debugging and audit trails.
        #
        # @return [Hash] Orphaned step data keyed by step_id
        #
        # @example
        #   wizard.orphaned_steps_data
        #   # => { email_uk: { email: 'uk@example.com' } }
        #
        # @api public
        def orphaned_steps_data
          all_raw_steps = raw_data[:steps] || {}

          all_raw_steps.except(*flow_path)
        end

        # Save current step data
        #
        # @return [void]
        #
        # @example
        #   wizard.current_step_valid? && wizard.save
        #
        # @api public
        def save
          step_data = current_step.serializable_data
          state_store.write_step(current_step_name, step_data)
        end

        # Write arbitrary data to state (deep merge)
        #
        # @param updates [Hash] Data to merge into state
        # @return [void]
        #
        # @example
        #   wizard.write_state(user_id: 1, submitted_at: Time.current)
        #
        # @api public
        def write_state(updates)
          state_store.write(updates)
        end

        # Clear all wizard data (destructive)
        #
        # **WARNING**: Removes all data including unreachable branches.
        #
        # @return [void]
        #
        # @api public
        def clear_state
          state_store.clear
        end

        # Read wizard data, filtered to reachable steps only
        #
        # Returns only data from steps that are currently reachable in the wizard
        # graph. Steps in unreachable branches (due to conditional branching) are
        # excluded.
        #
        # This is the **recommended** way to access wizard data. It keeps the state
        # focused on the current flow without stale branch data.
        #
        # @return [Hash] Data from reachable steps
        #
        # @example User chose "Non-UK" path
        #   wizard.data
        #   # => {
        #   #   steps: {
        #   #     name: { first_name: 'John', last_name: 'Doe' },
        #   #     email_non_uk: { email: 'non-uk@example.com' }
        #   #   }
        #   # }
        #   # Note: email_uk step is excluded (unreachable)
        #
        # @see StateAccess#raw_data For unfiltered view
        # @api public
        def data(source = raw_data)
          return {} unless source.is_a?(Hash)

          reachable = flow_path
          steps_data = source[:steps] || {}
          filtered_steps = steps_data.slice(*reachable)

          source.merge(steps: filtered_steps)
        end

        # Read step data, only if it's in the current path
        #
        # Returns step data only if the step is currently reachable.
        # Returns {} if:
        # - Step has no data
        # - Step is unreachable (in a different branch)
        # - Step doesn't exist
        #
        # @param step_id [Symbol] The step identifier
        # @return [Hash] Step data or {} if unreachable
        #
        # @example Step is reachable and has data
        #   wizard.step_data(:email)
        #   # => { email: 'user@example.com' }
        #
        # @example Step is in unreachable branch
        #   wizard.step_data(:email_uk)  # User chose Non-UK
        #   # => {}
        #
        # @see StateAccess#raw_step_data For unfiltered reads
        # @api public
        def step_data(step_id)
          data.dig(:steps, step_id) || {}
        end

        # Check if user has saved data for a step in current flow
        #
        # Returns true only if:
        # - Step is in the current reachable flow
        # - Step has non-empty data
        #
        # @param step_id [Symbol] The step identifier
        # @return [Boolean] true if step has saved data in current flow
        #
        # @example Step with data in current flow
        #   wizard.saved?(:name)  # => true
        #
        # @example Step unreachable (even if data exists)
        #   wizard.saved?(:email_uk)  # User chose Non-UK
        #   # => false
        #
        # @api public
        def saved?(step_id)
          step_data(step_id).present?
        end

        # Get saved path: array of steps with data in current flow
        #
        # Returns array of step IDs where user has entered data,
        # filtered to current flow path. Steps appear in flow order.
        #
        # May be shorter than {Navigation#flow_path} if user hasn't
        # completed all steps.
        #
        # @return [Array<Symbol>] Steps with saved data in current flow
        #
        # @example
        #   wizard.saved_path
        #   # => [:name, :nationality]
        #
        # @example User hasn't touched all steps
        #   # flow_path = [:name, :nationality, :right_to_work, :review]
        #   wizard.saved_path
        #   # => [:name]
        #
        # @see Navigation#flow_path For complete flow path
        # @see #saved? For individual step checks
        # @api public
        def saved_path
          flow_path.select { |step_id| saved?(step_id) }
        end

        # Mark wizard as completed without clearing data
        #
        # Sets a completion flag and timestamp in state. Data is preserved
        # for recovery, undo, or audit purposes.
        #
        # Useful for:
        # - Allowing browser back/recovery after completion
        # - Audit trails
        # - Analytics (track when completed)
        # - Undo functionality
        #
        # Unlike {StateAccess#clear_state}, this preserves all data.
        #
        # @return [void]
        #
        # @example
        #   wizard.mark_completed
        #   wizard.completed?  # => true
        #   wizard.completed_at  # => Time.current
        #
        # @see #completed?
        # @see #completed_at
        # @api public
        def mark_completed
          completed_at = Time.current
          state_store.write(completed: true, completed_at:)
        end

        # Check if wizard is marked as completed
        #
        # @return [Boolean] True if {#mark_completed} has been called
        #
        # @example
        #   wizard.completed?  # => false
        #   wizard.mark_completed
        #   wizard.completed?  # => true
        #
        # @api public
        def completed?
          raw_data[:completed].present?
        end

        # Get completion timestamp
        #
        # @return [Time, nil] Timestamp when {#mark_completed} was called, or nil
        #
        # @example
        #   wizard.completed_at
        #   # => 2025-11-15 18:30:00 +0000
        #
        # @api public
        def completed_at
          raw_data[:completed_at]
        end

        # Set wizard-level metadata
        #
        # Store arbitrary metadata without interfering with step data structure.
        # Useful for tracking context like user_id, session info, IP address, etc.
        #
        # @param key [Symbol, String] Metadata key
        # @param value [Object] Metadata value (must be serializable)
        # @return [void]
        #
        # @example
        #   wizard.set_metadata(:user_id, 123)
        #   wizard.set_metadata(:ip_address, '127.0.0.1')
        #   wizard.set_metadata(:form_version, 2)
        #
        # @see #get_metadata
        # @api public
        def set_metadata(key, value)
          state_store.write(key => value)
        end

        # Retrieve wizard metadata
        #
        # @param key [Symbol, String] Metadata key
        # @param default [Object] Default value if key not found
        # @return [Object] Metadata value or default
        #
        # @example
        #   wizard.get_metadata(:user_id)
        #   # => 123
        #
        # @example With default
        #   wizard.get_metadata(:missing_key, default: 'N/A')
        #   # => "N/A"
        #
        # @see #set_metadata
        # @api public
        def get_metadata(key, default: nil)
          raw_data.fetch(key, default)
        end

        # Get all metadata (non-step data)
        #
        # Returns everything from state except the `:steps` key.
        # Includes completion flags, custom metadata, etc.
        #
        # @return [Hash] All metadata
        #
        # @example
        #   wizard.all_metadata
        #   # => {
        #   #   user_id: 123,
        #   #   completed: true,
        #   #   completed_at: 2025-11-15 18:30:00 +0000,
        #   #   ip_address: '127.0.0.1'
        #   # }
        #
        # @api public
        def all_metadata
          raw_data.except(:steps)
        end
      end
    end
  end
end
