module DfE
  module Wizard
    module Core
      # StateFiltering: Path-aware filtering of wizard state
      #
      # Filters raw state to show only steps in the current wizard path.
      # Unreachable branch data is preserved in storage but not returned by default.
      #
      # This is the **smart filtering** layer that prevents stale data from
      # unreachable branches from polluting the wizard state.
      #
      # ## How it works
      #
      # When a user answers questions that branch the wizard (e.g., "UK" vs "Non-UK"),
      # both branches may have data in storage. This module filters reads to show only
      # the currently reachable path based on {#path_traversal}.
      #
      # ## Example scenario
      #
      # 1. User chooses "UK" → fills out UK-specific steps
      # 2. User goes back and changes to "Non-UK"
      # 3. UK steps are now unreachable (but still in storage)
      # 4. This module ensures only Non-UK steps are returned by {#data}
      #
      # @example Basic usage
      #   wizard.data  # Only reachable steps
      #   wizard.step_data(:email)  # Returns data only if step is reachable
      #   wizard.orphaned_steps_data  # See what's in unreachable branches
      #
      # @api public
      module StateFiltering
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
        def data
          filter_to_reachable_steps(raw_data)
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
          return {} unless path_traversal.include?(step_id)

          raw_step_data(step_id)
        end

        # Check if step has data AND is in current path
        #
        # Returns true only if:
        # - Step is in the current reachable path
        # - Step has non-empty data
        #
        # Useful for checking "has user visited this step in the current flow?"
        #
        # @param step_id [Symbol] The step identifier
        # @return [Boolean] True if step has data and is reachable
        #
        # @example Step is reachable with data
        #   wizard.step_data_present?(:email)
        #   # => true
        #
        # @example Step is unreachable (even with data)
        #   wizard.step_data_present?(:email_uk)  # User chose Non-UK
        #   # => false
        #
        # @see StateAccess#step_data_exists? For reachability-agnostic check
        # @api public
        def step_data_present?(step_id)
          path_traversal.include?(step_id) && raw_step_data(step_id).present?
        end

        # Get all step data from reachable steps
        #
        # Returns data from all steps in the current path. Optionally filter
        # to only include visited (non-empty) steps.
        #
        # @param only_visited [Boolean] Exclude empty steps
        # @return [Hash] Reachable step data keyed by step_id
        #
        # @example All reachable data
        #   wizard.all_steps_data
        #   # => { name: {...}, email: {...}, review: {...} }
        #
        # @example Only visited steps
        #   wizard.all_steps_data(only_visited: true)
        #   # => { name: {...}, email: {...} }
        #   # (review not included because it's empty)
        #
        # @api public
        def all_steps_data(only_visited: false)
          reachable = data[:steps] || {}
          return reachable unless only_visited

          reachable.select { |_, v| v.present? }
        end

        # Get steps in unreachable branches
        #
        # Returns steps that have data but are not in the current reachable path.
        # Useful for:
        # - Showing "alternate paths" in admin/debug views
        # - Cleanup diagnostics
        # - Audit trails
        #
        # @return [Hash] Orphaned step data keyed by step_id
        #
        # @example User changed from "UK" to "Non-UK"
        #   wizard.orphaned_steps_data
        #   # => { email_uk: { email: 'uk@example.com' } }
        #
        # @api public
        def orphaned_steps_data
          all_raw_steps = raw_data[:steps] || {}
          reachable = path_traversal

          all_raw_steps.except(*reachable)
        end

        private

        # Filter state to only include reachable steps
        #
        # Core filtering logic: takes raw state and returns a copy with only
        # reachable steps based on {#path_traversal}.
        #
        # Preserves all non-step data (metadata, flags, etc).
        #
        # @param source [Hash] Raw state from storage
        # @return [Hash] Filtered state with only reachable steps
        #
        # @api private
        def filter_to_reachable_steps(source)
          return {} unless source.is_a?(Hash)

          reachable = path_traversal
          steps = source[:steps] || {}
          filtered_steps = steps.slice(*reachable)

          source.merge(steps: filtered_steps)
        end
      end
    end
  end
end
