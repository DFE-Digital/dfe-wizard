# frozen_string_literal: true

module DfE
  module Wizard
    module Core
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
        #   wizard.current_step.assign_attributes(params[:step])
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
              errors: current_step.errors.full_messages
            )
          end
        end

        # Validate a given step
        #
        # Checks if step passes validation rules.
        #
        # @return [Boolean] true if step is valid
        #
        # @api public
        def step_valid?(step_id)
          step(step_id).valid?
        end

        # Check if a step is accessible to the user
        #
        # A step is accessible if:
        # - It's the root step, OR
        # - It's in the current path AND all previous steps are valid
        #
        # Use this in controllers to prevent users jumping ahead.
        # Or to check user can return to review if can reach review
        #
        # @param step_id [Symbol] Step to check
        # @return [Boolean] true if step can be accessed
        #
        # @example In controller before_action
        #   def ensure_step_accessible
        #     render_404 unless @wizard.step_accessible?(params[:step])
        #   end
        #
        # @example Root step always accessible
        #   wizard.step_accessible?(:name)  # => true
        #
        # @example Step requires previous steps valid
        #   wizard.step_accessible?(:review)  # => false if name invalid
        #
        # @api public
        def step_accessible?(step_id)
          return true if step_id == steps_processor.root_node

          path = path_traversal(step_id)
          return false unless path.include?(step_id)

          # All previous steps must be valid
          previous_steps = path[0...-1]
          previous_steps.all? { |prev_id| step(prev_id).valid? }
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
        def current_step_accessible?
          step_accessible?(current_step_name)
        end
      end
    end
  end
end
