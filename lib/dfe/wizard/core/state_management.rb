# frozen_string_literal: true

module DfE
  module Wizard
    module Core
      # State management for wizard data persistence and access
      #
      # Provides a high-level interface to read, write, and manage wizard state
      # via the backing state store. Abstracts away direct store access, allowing
      # wizards to focus on data semantics rather than storage mechanics.
      #
      # Key feature: **Smart data filtering**. When accessing wizard data, only returns
      # data from steps currently reachable in the wizard path. This prevents stale data
      # from unreachable branches from polluting the wizard state.
      #
      # Example: If user answers "UK" then switches to "Non-UK", the "UK path" steps
      # are still in storage but not returned by default. This keeps the wizard focused
      # on the actual current flow while preserving data for audit/undo.
      #
      # @api public
      module StateManagement
        # Read the complete wizard data from the state store (all branches)
        #
        # Returns the full, unfiltered state dictionary including data from unreachable
        # branches. Use this only when you need the complete history/audit trail.
        #
        # Structure:
        # ```
        # {
        #   steps: {
        #     step_name: { attr1: value1, attr2: value2 },
        #     ...
        #   }
        # }
        # ```
        #
        # @return [Hash] Complete wizard state (including orphaned branches)
        #
        # @example
        #   wizard.raw_data
        #   # => { steps: { name: {...}, email_uk: {...}, email_non_uk: {...} } }
        #   # Even though only one email branch is reachable, both are returned
        #
        # @api public
        def raw_data
          state_store.read
        end

        # Read the complete wizard data, filtered to only reachable steps
        #
        # Returns only data from steps that are currently reachable in the wizard graph.
        # Steps in unreachable branches (due to conditional branching) are excluded.
        #
        # This is the **default** and recommended way to access data. Keeps the wizard
        # focused on the current flow without stale branch data.
        #
        # @return [Hash] Wizard data filtered to reachable steps
        #
        # @example User chose "Non-UK" path
        #   wizard.data
        #   # => { steps: { name: {...}, email_non_uk: {...} } }
        #   # email_uk step is excluded because it's unreachable
        #
        # @api public
        def data
          filter_reachable_data
        end

        # Read data for a specific step from the reachable path
        #
        # Convenience method for accessing a single step's data without fetching
        # the entire state dictionary. Only returns data if the step is currently reachable.
        #
        # Returns {} if:
        # - Step has no data
        # - Step is unreachable (in a different branch)
        #
        # @param step_id [Symbol] The step identifier
        # @return [Hash] Step data, or {} if not found or unreachable
        #
        # @example Step is reachable and has data
        #   wizard.step_data(:email)
        #   # => { email: "user@example.com" }
        #
        # @example Step is in unreachable branch
        #   wizard.step_data(:email_uk)  # User chose Non-UK
        #   # => {}
        #
        # @api public
        def step_data(step_id)
          return {} unless step_in_current_path?(step_id)

          read_step_data(step_id)
        end

        # Read raw step data (including from unreachable branches)
        #
        # For internal use and debugging. Returns step data even if unreachable.
        #
        # @param step_id [Symbol] The step identifier
        # @return [Hash] Step data
        #
        # @api private
        def raw_step_data(step_id)
          raw_steps[step_id] || {}
        end

        # Check if a step has any data (ignoring reachability)
        #
        # Useful for diagnostics: "Did user ever visit this step?"
        # Returns true even if the step is now unreachable.
        #
        # @param step_id [Symbol] The step identifier
        # @return [Boolean]
        #
        # @example
        #   wizard.step_data_exists?(:email_uk)  # => true (even if unreachable now)
        #
        # @api public
        def step_data_exists?(step_id)
          raw_step_data(step_id).present?
        end

        # Check if a step is in the current reachable path
        #
        # True if the step exists in the wizard graph path given current data.
        #
        # @param step_id [Symbol] The step identifier
        # @return [Boolean]
        def step_in_current_path?(step_id)
          path_traversal.include?(step_id)
        end

        # Check if a step has data AND is in the current path
        #
        # Useful for checking "has user visited this step in the current flow?"
        #
        # @param step_id [Symbol] The step identifier
        # @return [Boolean]
        #
        # @example
        #   wizard.step_data_present?(:email)  # => true only if visited AND reachable
        def step_data_present?(step_id)
          step_in_current_path?(step_id) && step_data(step_id).present?
        end

        # Get all step data, filtered to current path
        #
        # Only returns steps that are currently reachable.
        #
        # @param only_visited [Boolean] If true, only include steps with data
        # @return [Hash] All reachable step data keyed by step_id
        #
        # @example Get all reachable data
        #   wizard.all_steps_data
        #   # => { name: {...}, email: {...}, review: {...} }
        #
        # @example Only visited steps in current path
        #   wizard.all_steps_data(only_visited: true)
        #   # => { name: {...}, email: {...} }
        def all_steps_data(only_visited: false)
          reachable_steps = path_traversal
          steps_data = reachable_steps_data

          result = steps_data.select { |step_id, _| reachable_steps.include?(step_id) }
          return result unless only_visited

          result.select { |_, step_data| step_data.present? }
        end

        # Get all steps that exist in storage (including unreachable)
        #
        # Useful for auditing, debugging, or showing "alternate paths not taken".
        #
        # @return [Hash] All step data from raw storage
        #
        # @api public
        def all_steps_data_unfiltered
          raw_steps
        end

        # Get steps in unreachable branches (for diagnostics/audit)
        #
        # Returns steps that have data but are not in the current reachable path.
        # Useful for showing "alternate paths" or cleanup diagnostics.
        #
        # @return [Hash] Unreachable step data keyed by step_id
        #
        # @example User changed from "UK" to "Non-UK"
        #   wizard.orphaned_steps_data
        #   # => { email_uk: {...} }
        def orphaned_steps_data
          reachable_steps = path_traversal
          raw_steps.except(*reachable_steps)
        end

        # Save the current step's data to the state store
        #
        # Persists the current step object's serializable data. Should be called
        # after form submission and validation.
        #
        # Data is saved to raw storage; filtering happens on read.
        #
        # @return [void]
        #
        # @example
        #   if wizard.valid_step?
        #     wizard.save
        #     redirect_to wizard.next_step_path
        #   end
        def save
          step_data = current_step.serializable_data
          state_store.write_step(current_step_name, step_data)
        end

        # Write arbitrary data to state store
        #
        # Lower-level method for writing data outside the current step context.
        # Typically used for bulk updates, metadata, or system-level state.
        #
        # Performs a deep merge: new data is merged with existing state, not replacing it.
        #
        # @param updates [Hash] Data to merge into state
        # @return [void]
        #
        # @example Store submission metadata
        #   wizard.write_state(submitted_at: Time.current, by_user_id: user.id)
        def write_state(updates)
          state_store.write(updates)
        end

        # Clear all wizard data from state store
        #
        # WARNING: This is destructive and removes all data including unreachable branches.
        # Usually called after wizard completion. Consider using `mark_completed` if you
        # want to preserve state for audit/undo purposes.
        #
        # @return [void]
        #
        # @example
        #   wizard.complete!
        #   wizard.clear_state
        def clear_state
          state_store.clear
        end

        # Mark wizard as completed without destroying data
        #
        # Useful for:
        # - Allowing browser back/recovery
        # - Audit trails
        # - Undo functionality
        # - Analytics (see when it was completed)
        #
        # Preserves all data (reachable and unreachable branches) for recovery.
        #
        # @return [void]
        #
        # @example
        #   wizard.mark_completed
        #   wizard.data[:completed_at]  # => Time.current
        def mark_completed
          state_store.write(completed: true, completed_at: Time.current)
        end

        # Check if wizard has been marked as completed
        #
        # @return [Boolean]
        def completed?
          raw_data[:completed] == true
        end

        # Get completion timestamp
        #
        # @return [Time, nil]
        def completed_at
          raw_data[:completed_at]
        end

        # Update metadata without touching step data
        #
        # Useful for storing wizard-level context (user_id, session info, etc.)
        # without interfering with step data structure.
        #
        # @param key [Symbol, String]
        # @param value [Object]
        # @return [void]
        def set_metadata(key, value)
          state_store.write(key => value)
        end

        # Retrieve wizard metadata
        #
        # @param key [Symbol, String]
        # @param default [Object]
        # @return [Object]
        def get_metadata(key, default: nil)
          raw_data.fetch(key, default)
        end

        # Get all metadata (everything except :steps)
        #
        # @return [Hash]
        def all_metadata
          raw_data.except(:steps)
        end

        # Check if state store is available and working
        #
        # @return [Boolean]
        def state_store_available?
          state_store&.respond_to?(:read)
        end

        # Get a summary of state store health/stats
        #
        # Shows both reachable and total data for diagnostics.
        #
        # @return [Hash]
        #
        # @example
        #   wizard.state_summary
        #   # => {
        #   #   steps_reachable: 5,
        #   #   steps_with_data_reachable: 3,
        #   #   steps_total_in_storage: 7,
        #   #   orphaned_steps: 2,
        #   #   completed: false,
        #   #   state_key: "abc-123"
        #   # }
        def state_summary
          reachable = all_steps_data
          orphaned = orphaned_steps_data

          {
            steps_reachable: path_traversal.length,
            steps_with_data_reachable: reachable.count { |_, v| v.present? },
            steps_total_in_storage: all_steps_data_unfiltered.length,
            orphaned_steps: orphaned.length,
            completed: completed?,
            completed_at: completed_at,
            state_key: state_store.state_key,
            metadata_keys: all_metadata.keys,
          }
        end

        # Export wizard data in a structured format for external use
        #
        # By default, only exports reachable data. Use `include_orphaned: true`
        # to include steps from unreachable branches.
        #
        # Useful for:
        # - Building domain objects
        # - API responses
        # - CSV/PDF export
        # - Analytics pipelines
        #
        # @param include_metadata [Boolean] Include non-step data
        # @param only_visited [Boolean] Only include steps with data
        # @param include_orphaned [Boolean] Include unreachable branch data
        # @return [Hash]
        #
        # @example Export only current path
        #   export = wizard.export(only_visited: true)
        #
        # @example Export everything (for audit)
        #   export = wizard.export(include_orphaned: true)
        def export(include_metadata: true, only_visited: false, include_orphaned: false)
          steps = all_steps_data(only_visited: only_visited)
          steps.merge!(orphaned_steps_data) if include_orphaned

          result = { steps: steps }
          result.merge!(all_metadata) if include_metadata
          result
        end

        # Batch update multiple steps efficiently
        #
        # Avoids multiple state_store writes by grouping updates.
        #
        # @param updates [Hash<Symbol, Hash>] Map of step_id => step_data
        # @return [void]
        def batch_write_steps(updates)
          current_steps = all_steps_data_unfiltered
          state_store.write(steps: current_steps.deep_merge(updates))
        end

        # Verify that required steps have been completed in current path
        #
        # Only checks steps in the current reachable path. Ignores unreachable branches.
        #
        # @param required_steps [Array<Symbol>] Steps that must have data
        # @return [Boolean] True if all required steps have data
        #
        # @example
        #   unless wizard.required_steps_complete?([:name, :email])
        #     raise "Please fill in name and email"
        #   end
        def required_steps_complete?(*required_steps)
          required_steps.all? { |step| step_data_present?(step) }
        end

        # Get missing required steps (only from current path)
        #
        # @param required_steps [Array<Symbol>]
        # @return [Array<Symbol>] Steps that have no data or are unreachable
        def missing_required_steps(*required_steps)
          required_steps.reject { |step| step_data_present?(step) }
        end

        # Rollback to a previous version of state
        #
        # Requires state store to support versioning.
        # Useful for undo/recovery flows.
        #
        # @param version [Integer, String] Version identifier or timestamp
        # @return [Boolean] True if rollback succeeded
        def rollback_to(version:)
          if state_store.respond_to?(:rollback)
            state_store.rollback(version)
          else
            raise NotImplementedError, 'State store does not support rollback'
          end
        end

        private

        # Read raw step data from storage (no filtering)
        #
        # @param step_id [Symbol]
        # @return [Hash]
        def read_step_data(step_id)
          raw_steps[step_id] || {}
        end

        # Extract the steps hash from any data structure
        #
        # Handles nil safely and returns empty hash if no steps.
        #
        # @param source [Hash] The data hash (raw_data or data)
        # @return [Hash] The steps sub-hash
        # @api private
        def extract_steps(source)
          source&.dig(:steps) || {}
        end

        # Extract the steps hash from raw storage
        #
        # @return [Hash]
        # @api private
        def raw_steps
          extract_steps(raw_data)
        end

        # Extract the steps hash from filtered data
        #
        # @return [Hash]
        # @api private
        def reachable_steps_data
          extract_steps(data)
        end

        # Filter raw data to only include steps in current reachable path
        #
        # This is the magic: keeps the state store clean by hiding unreachable branches.
        # Data is preserved in storage but not returned by default.
        #
        # IMPORTANT: Uses steps_processor directly to avoid circular dependency
        # with path_traversal (which calls data()).
        #
        # @return [Hash] Filtered data with only reachable steps
        # @api private
        def filter_reachable_data
          reachable_paths = steps_processor.path_traversal(nil, raw_data)

          raw_data.transform_values do |value|
            value.is_a?(Hash) ? value.slice(*reachable_paths) : value
          end
        end
      end
    end
  end
end
