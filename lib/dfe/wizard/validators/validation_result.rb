# frozen_string_literal: true

module DfE
  module Wizard
    module Validators
      # Immutable value object representing the validation state of a single step
      #
      # Returned by {StepValidator#call} to represent whether a step is:
      # - Visited (has data in state store)
      # - Valid (passes step validation rules)
      # - What errors exist (validation error messages)
      #
      # Frozen for safety - cannot be modified after creation.
      #
      # @api public
      class ValidationResult
        # The step identifier
        # @return [Symbol]
        attr_reader :step_id

        # Whether the step has been visited (has data in state store)
        # @return [Boolean]
        attr_reader :visited

        # Validation status: true/false/nil for unvisited
        # @return [Boolean, nil]
        attr_reader :valid

        # Validation error messages (empty if valid)
        # @return [Array<String>]
        attr_reader :errors

        # Initialize a validation result
        #
        # @param step_id [Symbol] The step identifier
        # @param visited [Boolean] Whether step has data
        # @param valid [Boolean, nil] Validation status (nil for unvisited)
        # @param errors [Array<String>] Validation error messages
        #
        # @api private
        def initialize(step_id:, visited:, valid:, errors: [])
          @step_id = step_id
          @visited = visited
          @valid = valid
          @errors = errors.freeze
          freeze
        end

        # Check if step is valid
        #
        # @return [Boolean]
        #
        # @example
        #   result.valid?  # => true/false
        def valid?
          @valid.present?
        end

        # Check if step is invalid
        #
        # @return [Boolean]
        #
        # @example
        #   result.invalid?  # => true/false
        def invalid?
          @valid.blank?
        end

        # Check if step has been visited
        #
        # @return [Boolean]
        #
        # @example
        #   result.visited?  # => true/false
        def visited?
          @visited
        end

        # Check if step has NOT been visited
        #
        # @return [Boolean]
        #
        # @example
        #   result.unvisited?  # => true/false
        def unvisited?
          !@visited
        end

        # Convert to hash representation
        #
        # Useful for JSON serialization or logging.
        #
        # @return [Hash]
        #
        # @example
        #   result.to_h
        #   # => {
        #   #   step_id: :email,
        #   #   visited: true,
        #   #   valid: false,
        #   #   errors: ["Email is invalid"]
        #   # }
        def to_h
          {
            step_id: step_id,
            visited: visited,
            valid: valid,
            errors: errors,
          }
        end

        # Factory: Create a valid result
        #
        # @param step_id [Symbol]
        # @return [ValidationResult] Step that passed validation
        #
        # @example
        #   result = ValidationResult.valid(:email)
        #   result.valid?    # => true
        #   result.visited?  # => true
        #   result.errors    # => []
        def self.valid(step_id)
          new(step_id: step_id, visited: true, valid: true, errors: [])
        end

        # Factory: Create an invalid result
        #
        # @param step_id [Symbol]
        # @param errors [Array<String>] Error messages
        # @return [ValidationResult] Step with validation errors
        #
        # @example
        #   result = ValidationResult.invalid(:email, ["Email is required", "Email format is invalid"])
        #   result.valid?    # => false
        #   result.visited?  # => true
        #   result.errors    # => ["Email is required", "Email format is invalid"]
        def self.invalid(step_id, errors)
          new(step_id: step_id, visited: true, valid: false, errors: errors)
        end

        # Factory: Create an unvisited result
        #
        # @param step_id [Symbol]
        # @return [ValidationResult] Step with no data
        #
        # @example
        #   result = ValidationResult.unvisited(:email)
        #   result.visited?  # => false
        #   result.valid?    # => false (neither valid nor invalid)
        #   result.invalid?  # => false
        #   result.errors    # => []
        def self.unvisited(step_id)
          new(step_id: step_id, visited: false, valid: nil, errors: [])
        end
      end
    end
  end
end
