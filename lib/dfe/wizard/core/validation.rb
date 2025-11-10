# frozen_string_literal: true

module DfE
  module Wizard
    module Core
      # Step and path validation
      #
      # Validates individual steps and complete paths. Uses pure validators
      # that evaluate fresh on each call with no caching.
      #
      # @api public
      module Validation
        # Check if the CURRENT step is valid
        #
        # Validates the step object against its rules (presence, format, etc).
        # This is what you call after a user submits a step form.
        #
        # Does NOT:
        # - Check if all previous steps are complete
        # - Check if path is reachable
        # - Validate unsaved hypothetical data
        #
        # @return [Boolean] true if current step passes validation
        #
        # @example User submits email form
        #   wizard.current_step.assign_attributes(email: "user@example.com")
        #   wizard.valid_step?  # => true
        #
        # @example User submits blank form
        #   wizard.current_step.assign_attributes(email: "")
        #   wizard.valid_step?  # => false
        def valid_step?
          current_step.valid?
        end

        # Check if a specific step is valid
        #
        # Validates a step that already has data in the state store.
        # Returns false if step has no data (unvisited).
        #
        # Does NOT:
        # - Check if this step must be completed before returning to review
        # - Validate unsaved or hypothetical data
        # - Check graph reachability
        #
        # @param step_id [Symbol] The step identifier to validate
        # @return [Boolean] true if step has data and is valid
        #
        # @example Check if saved email is valid
        #   # Data in state: { steps: { email: { email: "user@example.com" } } }
        #   wizard.step_valid?(:email)  # => true
        #
        # @example Step never visited (no data)
        #   # Data in state: { steps: {} }
        #   wizard.step_valid?(:email)  # => false (unvisited, can't validate)
        #
        # @example Step visited but with invalid data
        #   # Data in state: { steps: { email: { email: "invalid" } } }
        #   wizard.step_valid?(:email)  # => false (invalid data)
        def step_valid?(step_id)
          step_validator.valid?(step_id)
        end

        # Check if a specific step has been visited (has data)
        #
        # Only checks if step exists in state store. Does NOT validate it.
        # A step can be visited but invalid (bad data saved).
        #
        # Does NOT:
        # - Validate the data
        # - Check if step is required for the path
        # - Check graph reachability
        #
        # @param step_id [Symbol] The step identifier
        # @return [Boolean] true if step has data in state store
        #
        # @example User answered the step
        #   # Data: { steps: { email: { email: "invalid" } } }
        #   wizard.step_visited?(:email)  # => true (has data)
        #   wizard.step_valid?(:email)    # => false (but invalid)
        #
        # @example User never visited this step
        #   # Data: { steps: {} }
        #   wizard.step_visited?(:email)  # => false
        def step_visited?(step_id)
          step_validator.visited?(step_id)
        end

        # Check if all steps UP TO a target are both visited AND valid
        #
        # This is the "ready to return to review" check.
        # Both conditions must be true for each step in path:
        # 1. All steps have been visited (has data)
        # 2. All steps have valid data
        #
        # Use together with {#path_valid_to?} for return-to-review pattern.
        #
        # Does NOT:
        # - Check if path exists in graph (see {#completed_to?})
        # - Check individual step validation (see {#first_invalid_step})
        # - Check if specific steps are incomplete (see {#first_unvisited_step})
        #
        # @param target_step [Symbol] The target step (usually :review)
        # @return [Boolean] true if all steps in path are visited and valid
        #
        # @example Ready to return to review
        #   # Path: name -> email -> review
        #   # Data: { name: {...}, email: {...} }
        #   # Both steps are filled and valid
        #
        #   wizard.path_complete_to?(:review)  # => true
        #   wizard.path_valid_to?(:review)     # => true
        #   wizard.handle_return_to_check_your_answers(:review)  # => :review
        #
        # @example User hasn't filled all steps
        #   # Data: { name: {...} }  - email missing
        #   wizard.path_complete_to?(:review)  # => false
        #   # Can't return to review yet
        #
        # @example One step has invalid data
        #   # Data: { name: {...}, email: {email: "invalid"} }
        #   wizard.path_complete_to?(:review)  # => true - all visited
        #   wizard.path_valid_to?(:review)     # => false - email invalid
        def path_complete_to?(target_step)
          path_validator.complete_to?(target_step)
        end

        # Check if all visited steps UP TO a target are valid
        #
        # Only checks validation of visited steps. Does NOT require all steps visited.
        # Unvisited steps are not checked.
        #
        # Often used with {#path_complete_to?} to ensure path is both
        # complete (all visited) and valid (all correct).
        #
        # Does NOT:
        # - Require all steps to be visited
        # - Check if path exists in graph
        # - Find which steps are invalid (see {#first_invalid_step})
        #
        # @param target_step [Symbol] The target step
        # @return [Boolean] true if all visited steps are valid
        #
        # @example All visited steps are valid
        #   # Data: { name: {...}, email: {...} }
        #   wizard.path_valid_to?(:review)  # => true
        #
        # @example One visited step is invalid
        #   # Data: { name: {...}, email: {email: "invalid"} }
        #   wizard.path_valid_to?(:review)  # => false
        #
        # @example Some steps unvisited but what's filled is valid
        #   # Data: { name: {...} }  - email never visited
        #   wizard.path_valid_to?(:review)  # => true (no invalid data)
        def path_valid_to?(target_step)
          path_validator.valid_to?(target_step)
        end

        # Check if current step is accessible
        #
        # A step is accessible if:
        # - It's the root step, OR
        # - All previous steps in the path are both visited AND valid
        #
        # This prevents users from jumping to steps without completing
        # required previous steps. Used by controllers to show 404 for
        # unauthorized direct access.
        #
        # @return [Boolean] true if current step can be accessed
        #
        # @example Check if step is accessible
        #   wizard = MyWizard.new(current_step: :confirmation, state_store: store)
        #   wizard.current_step_accessible?  # => false (missing previous steps)
        #
        # @example At root step
        #   wizard = MyWizard.new(current_step: :name, state_store: store)
        #   wizard.current_step_accessible?  # => true (always accessible)
        #
        # @example In controller
        #   def show
        #     return render_404 unless @wizard.current_step_accessible?
        #     render :new
        #   end
        #
        # @api public
        def current_step_accessible?
          step_accessible?(current_step_name)
        end

        # Check if a specific step is accessible
        #
        # A step is accessible if:
        # - It's the root step, OR
        # - It's in the current path AND all previous steps are visited and valid
        #
        # @param step_id [Symbol] Step to check
        # @return [Boolean] true if step is accessible
        #
        # @example Root step is always accessible
        #   wizard.step_accessible?(:name)  # => true
        #
        # @example Step not in path (unreachable)
        #   wizard.step_accessible?(:immigration_status)  # => false
        #   # (if nationality = UK, immigration_status is skipped)
        #
        # @example Step in path but previous step invalid
        #   # Data: { name: {first_name: ''}, email: {...} }
        #   wizard.step_accessible?(:review)  # => false
        #   # (name is invalid, can't reach review)
        #
        # @example Step in path and all previous steps valid
        #   # Data: { name: {...}, email: {...} }
        #   wizard.step_accessible?(:review)  # => true
        #
        # @api public
        def step_accessible?(step_id)
          return true if step_id == steps_processor.root_node

          path = path_traversal(step_id)
          return false unless path.include?(step_id)

          # Check all previous steps are visited and valid
          previous_steps = path[0...-1]

          previous_steps.all? do |prev_step_id|
            step_visited?(prev_step_id) && step_valid?(prev_step_id)
          end
        end

        # Get validated path to target
        #
        # Returns array of step IDs in path, but only if ALL steps are visited AND valid.
        # Same interface as path_traversal, but with validation built-in.
        #
        # @param target_step [Symbol, nil] The target step (nil = current path)
        # @return [Array<Symbol>, nil] Path array if valid, nil if invalid
        #
        # @example Valid path
        #   wizard.validated_path_to(:review)  # => [:name, :email, :review]
        #
        # @example Invalid path
        #   wizard.validated_path_to(:review)  # => []
        def validated_path_to(target_step = nil)
          target = target_step || current_step_name
          return [] unless path_complete_to?(target) && path_valid_to?(target)

          path_traversal(target)
        end

        # Check if path to target is valid
        #
        # Boolean version of validated_path_to.
        # Returns true if all steps are visited and valid.
        #
        # @param target_step [Symbol, nil] The target step (nil = current path)
        # @return [Boolean]
        #
        # @example
        #   wizard.validated_path_to?(review)  # => true/false
        def validated_path_to?(target_step = nil)
          validated_path_to(target_step).include?(target_step)
        end

        # Get detailed validation results for entire path
        #
        # Returns a ValidationResult for each step showing:
        # - step_id: identifier
        # - visited: has data?
        # - valid: passes validation?
        # - errors: validation error messages
        #
        # Useful for inspecting each step's state individually.
        #
        # @param target_step [Symbol, nil] End point for path (nil = current path)
        # @return [Array<DfE::Wizard::Validators::ValidationResult>]
        #
        # @example
        #   results = wizard.validated_path(:review)
        #   results.each do |result|
        #     puts "#{result.step_id}:"
        #     puts "  Visited: #{result.visited?}"
        #     puts "  Valid: #{result.valid?}"
        #     puts "  Errors: #{result.errors.join(', ')}"
        #   end
        #   # Output:
        #   # name:
        #   #   Visited: true
        #   #   Valid: true
        #   #   Errors:
        #   # email:
        #   #   Visited: true
        #   #   Valid: false
        #   #   Errors: Email is invalid
        #   # review:
        #   #   Visited: false
        #   #   Valid: nil
        #   #   Errors:
        def validated_path(target_step = nil)
          path_validator.call(target_step)
        end

        # Find first invalid step in path
        #
        # Walks through path to find first step with validation errors.
        # Returns nil if all steps are valid.
        #
        # Useful for displaying which step has problems.
        #
        # @param target_step [Symbol, nil] End point for search (nil = current path)
        # @return [Symbol, nil] ID of first invalid step, or nil if all valid
        #
        # @example Display error page for first problem
        #   if step = wizard.first_invalid_step(target_step: :review)
        #     redirect_to wizard.step_path(step),
        #       alert: "Please fix errors in #{step}"
        #   end
        #
        # @example All steps valid
        #   wizard.first_invalid_step(target_step: :review)  # => nil
        def first_invalid_step(target_step: nil)
          path_validator.first_invalid(target_step: target_step)
        end

        # Find first unvisited step in path
        #
        # Walks through path to find first step with no data.
        # Returns nil if all steps are visited.
        #
        # Useful for resuming wizard from where user left off.
        #
        # @param target_step [Symbol, nil] End point for search (nil = current path)
        # @return [Symbol, nil] ID of first unvisited step, or nil if all visited
        #
        # @example Resume wizard from incomplete step
        #   step = wizard.first_unvisited_step(target_step: :review) || :review
        #   redirect_to wizard.step_path(step)
        #
        # @example All steps completed
        #   wizard.first_unvisited_step(target_step: :review)  # => nil
        def first_unvisited_step(target_step: nil)
          path_validator.first_unvisited(target_step: target_step)
        end
      end
    end
  end
end
