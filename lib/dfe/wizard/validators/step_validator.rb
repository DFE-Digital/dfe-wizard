# frozen_string_literal: true

module DfE
  module Wizard
    module Validators
      # Pure validator for individual wizard steps
      #
      # Validates a single step by checking if it has data in the state store
      # and if that data passes the step's validation rules.
      #
      # Stateless validator - no caching. Evaluates fresh on every call by:
      # 1. Reading step data from state store
      # 2. Instantiating the step class
      # 3. Running step validation
      # 4. Returning a ValidationResult
      #
      # @api public
      class StepValidator
        # Initialize validator
        #
        # @param wizard [DfE::Wizard] The wizard instance (for data/step access)
        #
        # @api private
        def initialize(wizard)
          @wizard = wizard
        end

        # Validate a step
        #
        # Checks if a step has been visited and is valid.
        # Returns a ValidationResult with status and any errors.
        #
        # Process:
        # 1. Check if step has data in state store
        # 2. If no data → return unvisited result
        # 3. If has data → instantiate step and validate it
        # 4. Return result with validation status and errors
        #
        # Evaluation is fresh on each call - no caching.
        #
        # @param step_id [Symbol] The step identifier to validate
        # @return [ValidationResult]
        #
        # @example Unvisited step (no data)
        #   # Data: { steps: {} }
        #   result = validator.call(:email)
        #   # => ValidationResult(step_id: :email, visited: false, valid: nil)
        #
        # @example Valid step
        #   # Data: { steps: { email: { email: "user@example.com" } } }
        #   result = validator.call(:email)
        #   # => ValidationResult(step_id: :email, visited: true, valid: true)
        #
        # @example Invalid step
        #   # Data: { steps: { email: { email: "invalid" } } }
        #   result = validator.call(:email)
        #   # => ValidationResult(
        #   #   step_id: :email,
        #   #   visited: true,
        #   #   valid: false,
        #   #   errors: ["Email format is invalid"]
        #   # )
        #
        # @api public
        def call(step_id)
          step_data = @wizard.read_step_data(step_id)
          step_klass = @wizard.find_step(step_id)

          # No data = unvisited
          return ValidationResult.unvisited(step_id) if step_data.empty?

          # Has data = validate it
          step_instance = step_klass.new(
            step_data.merge(wizard: @wizard, step_id: step_id),
          )

          if step_instance.valid?
            ValidationResult.valid(step_id)
          else
            ValidationResult.invalid(step_id, step_instance.errors.full_messages)
          end
        end

        # Check if a step is valid
        #
        # Convenience method - returns boolean instead of ValidationResult.
        # Returns false if step is unvisited (no data).
        #
        # @param step_id [Symbol]
        # @return [Boolean]
        #
        # @example
        #   validator.valid?(:email)  # => true/false
        def valid?(step_id)
          call(step_id).valid?
        end

        # Check if a step has been visited (has data)
        #
        # Returns true only if step has data in state store.
        # Does NOT validate the data.
        #
        # @param step_id [Symbol]
        # @return [Boolean]
        #
        # @example
        #   validator.visited?(:email)  # => true/false
        def visited?(step_id)
          call(step_id).visited?
        end

        # Get validation errors for a step
        #
        # Returns empty array if step is valid or unvisited.
        # Returns array of error messages if step is invalid.
        #
        # @param step_id [Symbol]
        # @return [Array<String>]
        #
        # @example
        #   validator.errors_for(:email)
        #   # => ["Email format is invalid"]
        def errors_for(step_id)
          call(step_id).errors
        end
      end
    end
  end
end
