module DfE
  module Wizard
    module Operations
      # Validates the step object
      #
      # This is the first operation that runs on every step by default.
      # It checks if the step object is valid according to its validations.
      #
      # @example Usage in steps_operator
      #   def steps_operator
      #     DfE::Wizard::StepsOperator::Builder.draw(wizard: self, callable: state_store) do |b|
      #       b.on_step(:personal_details, use: [Validate, CreateRecord])
      #     end
      #   end
      class Validate
        # @return [Object] The underlying repository
        attr_reader :repository

        # @return [Object] The step object being validated
        attr_reader :step

        # Initialize validator
        #
        # @param repository [Object] The repository (unused, but included for consistency)
        # @param step [Object] The step object to validate
        def initialize(repository:, step:)
          @repository = repository
          @step = step
        end

        # Execute validation
        #
        # @example Result on success
        #   result = validate_op.execute
        #   # => { success: true }
        #
        # @example Result on failure
        #   result = validate_op.execute
        #   # => { success: false, errors: { first_name: ["can't be blank"] } }
        #
        # @return [Hash] Hash with :success key (and :errors if validation fails)
        def execute
          if @step.valid?
            { success: true }
          else
            { success: false, errors: @step.errors }
          end
        end

        # Rollback (no-op for validation)
        #
        # @return [void]
        def rollback
          # Validation cannot be rolled back
        end
      end
    end
  end
end
