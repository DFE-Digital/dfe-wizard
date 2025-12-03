module DfE
  module Wizard
    module Behaviours
      # Step and path validation for wizard flows
      #
      # Provides methods to validate individual steps and check accessibility.
      # Works directly with step objects and state store without extra layers.
      #
      # @api public
      module Validation
        # Validate the current step
        #
        # Checks if current step passes validation rules.
        # Call after user submits form data.
        #
        # @return [Boolean] true if current step is valid
        #
        # @example After form submission
        #
        #   if wizard.current_step_valid?
        #     wizard.save
        #     redirect_to wizard.next_step_path
        #   else
        #     render :show
        #   end
        #
        # @api public
        def current_step_valid?
          current_step.valid?.tap do |result|
            log_validation(
              type: :step,
              result: result,
              step: current_step_name,
              errors: current_step.errors.full_messages,
            )
          end
        end

        # Check if step data is valid
        #
        # @param step_id [Symbol] Step identifier
        # @return [Boolean] true if step passes validation
        #
        # @example
        #   wizard.valid?(:name)  # => true
        #
        # @api public
        def valid?(step_id)
          step(step_id).valid?
        end

        # Get steps that are valid (safe path) up to a step (default
        # to current step).
        #
        # Returns array of step IDs where data exists and passes validation.
        # Stops **before** an invalid step.
        #
        # @return [Array<Symbol>] Steps with valid data
        #
        # @example
        #   wizard.valid_path  # => [:name, :email]
        #
        # @api public
        def valid_path(target_step = current_step_name)
          flow_path(target_step).take_while { |step_id| valid?(step_id) }
        end

        # Check if can proceed to target step (all previous valid)
        #
        # Returns true if all steps before target have valid data.
        #
        # @param target_step [Symbol] Target step ID
        # @return [Boolean] true if can proceed
        #
        # @example Can user reach review?
        #   wizard.valid_path_to?(:review)  # => true
        #
        # @api public
        def valid_path_to?(target_step)
          return true if target_step == steps_processor.root_step

          path = flow_path(target_step)
          idx = path.index(target_step)
          return false unless idx

          previous = path[0...idx]
          previous.all? { |step_id| valid?(step_id) }
        end

        # Get hydrated step objects for valid steps
        #
        # @return [Array<DfE::Wizard::Step>]
        #
        # @api public
        def steps_valid
          valid_path.map { |step_id| step(step_id) }
        end

        # Check if current step is accessible
        #
        # Convenience method for checking current step.
        # Equivalent to `step_accessible?(current_step_name)`.
        #
        # @return [Boolean] true if current step can be accessed
        #
        # @example In controller
        #   def show
        #     render_404 unless @wizard.current_step_accessible?
        #   end
        #
        # @api public
        def valid_path_to_current_step?
          valid_path_to?(current_step_name)
        end
      end
    end
  end
end
