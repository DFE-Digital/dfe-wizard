module DfE
  module Wizard
    module Core
      # StateLifecycle: Completion tracking, metadata, export, and audit
      #
      # Higher-level features for managing wizard lifecycle:
      # - Mark completion without destroying data
      # - Track metadata (user_id, timestamps, etc)
      # - Export state for external systems
      # - Diagnostic summaries
      #
      # Unlike StateAccess (low-level read/write) and StateFiltering (path-aware reads),
      # this module provides business-level operations for the wizard lifecycle.
      #
      # @example Completion workflow
      #   wizard.mark_completed
      #   export = wizard.export(include_metadata: true)
      #   send_to_external_system(export)
      #
      # @example Metadata tracking
      #   wizard.set_metadata(:user_id, current_user.id)
      #   wizard.set_metadata(:ip_address, request.remote_ip)
      #   summary = wizard.state_summary
      #
      # @api public
      module StateLifecycle
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

        # Export wizard data for external systems
        #
        # Returns a structured hash suitable for:
        # - Building domain objects
        # - API responses
        # - CSV/PDF export
        # - Analytics pipelines
        #
        # By default, exports only reachable data. Use options to customize.
        #
        # @param include_metadata [Boolean] Include non-step data (default: true)
        # @param only_visited [Boolean] Only include steps with data (default: false)
        # @param include_orphaned [Boolean] Include unreachable branch data (default: false)
        # @return [Hash] Exported state
        #
        # @example Export current path only
        #   export = wizard.export(only_visited: true)
        #   # => {
        #   #   steps: { name: {...}, email: {...} },
        #   #   user_id: 123,
        #   #   completed: true
        #   # }
        #
        # @example Export everything (for audit)
        #   export = wizard.export(include_orphaned: true)
        #   # => Includes email_uk AND email_non_uk branches
        #
        # @api public
        def export(include_metadata: true, only_visited: false, include_orphaned: false)
          steps = all_steps_data(only_visited:)
          steps.merge!(orphaned_steps_data) if include_orphaned

          result = { steps: }
          result.merge!(all_metadata) if include_metadata
          result
        end

        # Get state summary for diagnostics
        #
        # Returns high-level statistics about wizard state, useful for:
        # - Admin dashboards
        # - Debugging
        # - Health checks
        # - Logging
        #
        # @return [Hash] Summary with counts, flags, and metadata keys
        #
        # @example
        #   wizard.state_summary
        #   # => {
        #   #   steps_reachable: 5,
        #   #   steps_with_data_reachable: 3,
        #   #   steps_total_in_storage: 7,
        #   #   orphaned_steps: 2,
        #   #   completed: true,
        #   #   completed_at: 2025-11-15 18:30:00 +0000,
        #   #   metadata_keys: [:user_id, :ip_address]
        #   # }
        #
        # @api public
        def state_summary
          {
            steps_reachable: path_traversal.length,
            steps_with_data_reachable: all_steps_data.count { |_, v| v.present? },
            steps_total_in_storage: (raw_data[:steps] || {}).length,
            orphaned_steps: orphaned_steps_data.length,
            completed: completed?,
            completed_at:,
            metadata_keys: all_metadata.keys,
          }
        end

        # Check if state store is available
        #
        # Verifies that the state_store exists and responds to `read`.
        #
        # @return [Boolean] True if state store is available
        #
        # @example
        #   wizard.state_store_available?
        #   # => true
        #
        # @api public
        def state_store_available?
          state_store.present? && state_store.respond_to?(:read)
        end
      end
    end
  end
end
