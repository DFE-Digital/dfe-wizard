module DfE
  module Wizard
    module Core
      # State management and data persistence
      #
      # Provides high-level API for reading/writing wizard state with automatic
      # transformation between flat repository storage and nested step structure.
      #
      # ## Architecture
      #
      # - **Repository**: Stores flat hash internally for efficiency
      # - **Wizard**: Transforms to/from `{ steps: {...} }` structure externally
      # - **State Store**: Delegates read/write to repository
      #
      # ## Data Flow
      #
      # **Reading (Repository → Wizard API):**
      # ```
      # Repository: { first_name: 'John', email: 'john@example.com', user_id: 123 }
      #      ↓ unflatten_state
      # Wizard API: {
      #   steps: {
      #     personal_details: { first_name: 'John' },
      #     contact: { email: 'john@example.com' }
      #   },
      #   user_id: 123
      # }
      # ```
      #
      # **Writing (Wizard API → Repository):**
      # ```
      # Wizard API: { steps: { personal_details: { first_name: 'Jane' } } }
      #      ↓ flatten_state
      # Repository: { first_name: 'Jane' }
      # ```
      #
      # @api public
      module StateManagement
        # Read complete wizard data with nested step structure
        #
        # Returns all persisted state transformed from flat repository storage
        # to nested `{ steps: {...} }` structure. Includes all steps (even
        # unreachable) plus metadata.
        #
        # Use {#data} for filtered view (reachable steps only).
        #
        # @return [Hash] All persisted state with nested steps
        #
        # @example
        #   wizard.raw_data
        #   # => {
        #   #   steps: {
        #   #     personal_details: { name: 'John' },
        #   #     contact: { email: 'john@example.com' },
        #   #     company: { name: 'ACME' }  # May be unreachable
        #   #   },
        #   #   user_id: 123,
        #   #   completed: true
        #   # }
        #
        # @see #data For filtered view (reachable steps only)
        # @api public
        def raw_data
          flat_hash = state_store.read
          unflatten_state(flat_hash).tap do |nested_data|
            log_state_read(data: nested_data)
          end
        end

        # Read data for specific step (unfiltered)
        #
        # Returns step data regardless of whether step is in current flow.
        # Useful for diagnostics and viewing unreachable branch data.
        #
        # @param step_id [Symbol] Step identifier
        # @return [Hash] Step data from `{ steps: { step_id: {...} } }` structure
        #
        # @example Reachable step
        #   wizard.raw_step_data(:personal_details)
        #   # => { name: 'John', email: 'john@example.com' }
        #
        # @example Unreachable step (still returns data if exists)
        #   wizard.raw_step_data(:company_details)  # User chose individual path
        #   # => { company_name: 'ACME' }  # Returns data even though unreachable
        #
        # @see #step_data For filtered view (returns {} if unreachable)
        # @api public
        def raw_step_data(step_id)
          raw_data.dig(:steps, step_id) || {}
        end

        # Check if step has any data (ignoring flow)
        #
        # Returns true if step has data, regardless of whether step is
        # currently reachable in the flow.
        #
        # @param step_id [Symbol] Step identifier
        # @return [Boolean] true if step has data
        #
        # @example
        #   wizard.step_data_exists?(:personal_details)  # => true
        #   wizard.step_data_exists?(:nonexistent)  # => false
        #
        # @api public
        def step_data_exists?(step_id)
          raw_step_data(step_id).present?
        end

        # Get all data from unreachable branches
        #
        # Returns steps with data that are not in the current flow path.
        # Useful for:
        # - Debugging branch logic
        # - Audit trails
        # - Detecting stale data from branch changes
        #
        # @return [Hash] Orphaned step data keyed by step_id
        #
        # @example User switched from business to individual
        #   wizard.orphaned_steps_data
        #   # => {
        #   #   company_details: { company_name: 'ACME', registration_number: '12345' }
        #   # }
        #
        # @see #data For view excluding orphaned data
        # @api public
        def orphaned_steps_data
          all_steps = raw_data[:steps] || {}
          all_steps.except(*flow_path)
        end

        # Save current step data to repository
        #
        # Validates current step, extracts serializable data, flattens it,
        # and merges into repository. Returns false if validation fails.
        #
        # @return [Boolean] true if save successful, false if validation failed
        #
        # @example
        #   if wizard.current_step.valid?
        #     wizard.save
        #   end
        #
        # @example Idiomatic usage
        #   wizard.save if wizard.current_step_valid?
        #
        # @see Validation#current_step_valid?
        # @api public
        def save
          return false unless current_step.valid?

          step_data = current_step.serializable_data

          state_store.write(step_data) # Repository merges flat attributes
          true
        end

        # Write arbitrary data to state (merge)
        #
        # Merges provided data into wizard state. Handles both nested
        # `{ steps: {...} }` structure and flat metadata updates.
        #
        # @param updates [Hash] Data to merge into state
        # @return [void]
        #
        # @example Update metadata
        #   wizard.write_state(user_id: 1, submitted_at: Time.current)
        #
        # @example Update step data (auto-flattens)
        #   wizard.write_state(
        #     steps: { personal_details: { name: 'Jane' } }
        #   )
        #
        # @api public
        def write_state(updates)
          if updates.key?(:steps)
            # Contains nested steps, flatten before writing
            flat_updates = flatten_state(updates)
            state_store.write(flat_updates)
          else
            # Pure metadata, write directly
            state_store.write(updates)
          end
        end

        # Clear all wizard data (destructive)
        #
        # **WARNING**: Removes all data including:
        # - All step data (reachable and unreachable)
        # - All metadata
        # - Completion flags
        #
        # Cannot be undone. Use with caution.
        #
        # @return [void]
        #
        # @example Reset wizard to initial state
        #   wizard.clear_state
        #   wizard.raw_data  # => {}
        #
        # @api public
        def clear_state
          state_store.clear
        end

        # Read wizard data, filtered to reachable steps only
        #
        # Returns only steps currently reachable in the wizard flow.
        # Steps in unreachable branches (due to conditional logic) are excluded.
        #
        # **This is the recommended method for accessing wizard data** as it
        # provides a clean view without stale branch data.
        #
        # @return [Hash] Data from reachable steps with `{ steps: {...} }` structure
        #
        # @example User chose "individual" path
        #   wizard.data
        #   # => {
        #   #   steps: {
        #   #     personal_details: { name: 'John' },
        #   #     account_type: { account_type: 'individual' },
        #   #     verification: { type: 'email' }
        #   #   },
        #   #   user_id: 123
        #   # }
        #   # Note: company_details excluded (unreachable in individual path)
        #
        # @see #raw_data For unfiltered view (all steps)
        # @api public
        def data
          all_data = raw_data
          reachable_steps = flow_path

          all_steps = all_data[:steps] || {}
          filtered_steps = all_steps.slice(*reachable_steps)

          all_data.merge(steps: filtered_steps)
        end

        # Read step data, only if it's in the current path
        #
        # Returns step data only if the step is currently reachable.
        # Returns empty hash if:
        # - Step has no data
        # - Step is unreachable (in a different branch)
        # - Step doesn't exist
        #
        # @param step_id [Symbol] The step identifier
        # @return [Hash] Step data or {} if unreachable/empty
        #
        # @example Step is reachable and has data
        #   wizard.step_data(:personal_details)
        #   # => { name: 'John', email: 'john@example.com' }
        #
        # @example Step is in unreachable branch
        #   wizard.step_data(:company_details)  # User chose individual
        #   # => {}
        #
        # @see #raw_step_data For unfiltered reads
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
        #   wizard.saved?(:personal_details)  # => true
        #
        # @example Step unreachable (even if data exists)
        #   wizard.saved?(:company_details)  # User chose individual
        #   # => false (unreachable, so considered "not saved")
        #
        # @see #step_data_exists? For unfiltered check
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
        # @example Partial completion
        #   # flow_path: [:name, :email, :verification, :review]
        #   wizard.saved_path
        #   # => [:name, :email]  # User stopped at email step
        #
        # @example After branch change
        #   # User switched from business to individual path
        #   wizard.saved_path
        #   # => [:personal_details, :account_type]
        #   # Note: company_details excluded (now unreachable)
        #
        # @see Navigation#flow_path For complete flow
        # @see #saved? For individual step checks
        # @api public
        def saved_path
          flow_path.select { |step_id| saved?(step_id) }
        end

        # Mark wizard as completed without clearing data
        #
        # Sets a completion flag and timestamp in state. Data is preserved
        # for recovery, audit, or analytics purposes.
        #
        # Useful for:
        # - Allowing browser back/recovery after completion
        # - Audit trails and compliance
        # - Analytics (track completion time)
        # - Implementing undo functionality
        #
        # Unlike {#clear_state}, this preserves all wizard data.
        #
        # @return [void]
        #
        # @example
        #   wizard.mark_completed
        #   wizard.completed?  # => true
        #   wizard.completed_at  # => 2025-11-22 22:03:00 +0000
        #
        # @see #completed?
        # @see #completed_at
        # @api public
        def mark_completed
          completed_at = Time.current
          state_store.write(completed: true, completed_at: completed_at)
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
        # @see #mark_completed
        # @api public
        def completed?
          raw_data[:completed].present?
        end

        # Get completion timestamp
        #
        # Returns the timestamp when {#mark_completed} was called.
        # Returns nil if wizard has not been marked as completed.
        #
        # @return [Time, nil] Completion timestamp or nil
        #
        # @example
        #   wizard.completed_at
        #   # => 2025-11-22 22:03:00 +0000
        #
        # @example Not yet completed
        #   wizard.completed_at  # => nil
        #
        # @see #mark_completed
        # @api public
        def completed_at
          raw_data[:completed_at]
        end

        # Set wizard-level metadata
        #
        # Store arbitrary metadata without interfering with step data structure.
        # Useful for tracking context like user_id, session info, IP address,
        # form version, etc.
        #
        # Metadata is preserved across step navigation and branch changes.
        #
        # @param key [Symbol, String] Metadata key
        # @param value [Object] Metadata value (must be serializable)
        # @return [void]
        #
        # @example Track user context
        #   wizard.set_metadata(:user_id, 123)
        #   wizard.set_metadata(:ip_address, request.remote_ip)
        #   wizard.set_metadata(:form_version, 2)
        #
        # @example Track timing
        #   wizard.set_metadata(:started_at, Time.current)
        #
        # @see #get_metadata
        # @see #all_metadata
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
        # @example With default value
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
        # Includes completion flags, timestamps, custom metadata, etc.
        #
        # @return [Hash] All metadata
        #
        # @example
        #   wizard.all_metadata
        #   # => {
        #   #   user_id: 123,
        #   #   completed: true,
        #   #   completed_at: 2025-11-22 22:03:00 +0000,
        #   #   ip_address: '127.0.0.1',
        #   #   form_version: 2
        #   # }
        #
        # @see #set_metadata
        # @see #get_metadata
        # @api public
        def all_metadata
          raw_data.except(:steps)
        end

        private

        # Transform flat repository hash to nested step structure
        #
        # Groups attributes by their owning step and creates the external
        # `{ steps: {...} }` structure. Non-step attributes become metadata.
        #
        # @param flat_hash [Hash] Flat hash from repository
        # @return [Hash] Nested structure with `:steps` key
        #
        # @example
        #   flat = {
        #     first_name: 'John',
        #     email: 'john@example.com',
        #     user_id: 123,
        #     completed: true
        #   }
        #   unflatten_state(flat)
        #   # => {
        #   #   steps: {
        #   #     personal_details: { first_name: 'John' },
        #   #     contact: { email: 'john@example.com' }
        #   #   },
        #   #   user_id: 123,
        #   #   completed: true
        #   # }
        #
        # @api private
        def unflatten_state(flat_hash)
          steps = {}
          metadata = {}

          flat_hash.each do |key, value|
            # Find which step owns this attribute
            step_id = find_step_for_attribute(key)

            if step_id
              steps[step_id] ||= {}
              steps[step_id][key] = value
            else
              # Not a step attribute, must be metadata
              metadata[key] = value
            end
          end

          metadata.merge(steps: steps)
        end

        # Transform nested step structure to flat repository hash
        #
        # Flattens `{ steps: {...} }` structure to single-level hash
        # for efficient repository storage.
        #
        # @param nested_hash [Hash] Nested structure with `:steps` key
        # @return [Hash] Flat hash for repository
        #
        # @example
        #   nested = {
        #     steps: {
        #       personal_details: { first_name: 'John' },
        #       contact: { email: 'john@example.com' }
        #     },
        #     user_id: 123
        #   }
        #   flatten_state(nested)
        #   # => {
        #   #   first_name: 'John',
        #   #   email: 'john@example.com',
        #   #   user_id: 123
        #   # }
        #
        # @api private
        def flatten_state(nested_hash)
          flat = {}

          # Extract and flatten steps
          nested_hash[:steps]&.each_value do |step_data|
            flat.merge!(step_data)
          end

          # Extract metadata (everything except :steps)
          metadata = nested_hash.except(:steps)
          flat.merge!(metadata)

          flat
        end

        # Find which step owns an attribute
        #
        # Searches through all step definitions to find the step class
        # that declares the given attribute.
        #
        # @param attribute_name [Symbol, String] Attribute name
        # @return [Symbol, nil] Step ID that owns attribute, or nil if not found
        #
        # @example
        #   find_step_for_attribute(:first_name)  # => :personal_details
        #   find_step_for_attribute(:email)  # => :contact
        #   find_step_for_attribute(:user_id)  # => nil (metadata, not a step attribute)
        #
        # @api private
        def find_step_for_attribute(attribute_name)
          steps_processor.step_definitions.find do |node|
            step_class = node.klass
            next unless step_class.respond_to?(:attribute_names)

            step_class.attribute_names.map(&:to_sym).include?(attribute_name.to_sym)
          end&.id
        end
      end
    end
  end
end
