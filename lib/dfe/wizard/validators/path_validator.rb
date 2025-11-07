# frozen_string_literal: true

module DfE
  module Wizard
    module Validators
      # Pure validator for wizard paths
      #
      # Validates sequences of steps through the wizard. Validates each step
      # in the path using {StepValidator}.
      #
      # Stateless validator - no caching. Evaluates fresh on every call by:
      # 1. Getting path from wizard
      # 2. Validating each step in path
      # 3. Checking completion/validity across the path
      #
      # @api public
      class PathValidator
        # Initialize validator
        #
        # @param wizard [DfE::Wizard] The wizard instance
        # @param step_validator [StepValidator] The step validator to use
        #
        # @api private
        def initialize(wizard, step_validator)
          @wizard = wizard
          @step_validator = step_validator
        end

        # Validate entire path to target
        #
        # Returns a ValidationResult for each step in the path from root to target.
        # Evaluation is fresh on each call - no caching.
        #
        # Useful for:
        # - Inspecting each step's validation state
        # - Building detailed progress displays
        # - Logging wizard state
        #
        # @param target_step [Symbol, nil] End point for path (nil = full path)
        # @return [Array<ValidationResult>]
        #
        # @example Inspect path validation
        #   results = validator.call(:review)
        #   results.each do |result|
        #     puts "#{result.step_id}: visited=#{result.visited?}, valid=#{result.valid?}"
        #   end
        #   # Output:
        #   # name: visited=true, valid=true
        #   # email: visited=true, valid=false
        #   # review: visited=false, valid=nil
        #
        # @api public
        def call(target_step = nil)
          path = @wizard.path_traversal(target_step)

          path.map { |step_id| @step_validator.call(step_id) }
        end

        # Check if all steps UP TO target are visited AND valid
        #
        # Both conditions must be true for each step before target:
        # 1. Step is visited (has data in state store)
        # 2. Step is valid (passes validation)
        #
        # Returns false if:
        # - Any step in path is unvisited (missing data)
        # - Any step in path has validation errors
        # - Target step is not reachable
        #
        # Use with {#valid_to?} to check if ready for return-to-review.
        #
        # @param target_step [Symbol] The target step
        # @return [Boolean]
        #
        # @example Ready to return to review
        #   # Path: name -> email -> review
        #   # Data: { name: {...}, email: {...} }
        #   # Validation: Both valid
        #   validator.complete_to?(:review)  # => true
        #
        # @example Missing data
        #   # Data: { name: {...} }  - email missing
        #   validator.complete_to?(:review)  # => false
        #
        # @example Invalid data
        #   # Data: { name: {...}, email: {email: "invalid"} }
        #   # email fails validation
        #   validator.complete_to?(:review)  # => false
        #
        # @api public
        def complete_to?(target_step)
          steps_before(target_step).all? do |step_id|
            @step_validator.visited?(step_id)
          end
        end

        # Check if all VISITED steps UP TO target are valid
        #
        # Only checks validation of steps with data. Does NOT require:
        # - All steps to be visited
        # - Target to be reachable
        #
        # Returns true if all steps that have been visited are valid.
        # Unvisited steps are ignored.
        #
        # Use with {#complete_to?} to check if ready for return-to-review.
        #
        # @param target_step [Symbol] The target step
        # @return [Boolean]
        #
        # @example All visited steps valid
        #   # Data: { name: {...}, email: {...} }
        #   # Validation: Both valid
        #   validator.valid_to?(:review)  # => true
        #
        # @example One visited step invalid
        #   # Data: { name: {...}, email: {email: "invalid"} }
        #   validator.valid_to?(:review)  # => false
        #
        # @example Some unvisited (but what's filled is valid)
        #   # Data: { name: {...} }  - email unvisited
        #   # Validation: name is valid
        #   validator.valid_to?(:review)  # => true
        #
        # @api public
        def valid_to?(target_step)
          steps_before(target_step).all? do |step_id|
            @step_validator.valid?(step_id)
          end
        end

        # Find first invalid step in path
        #
        # Walks through path to find first step with validation errors.
        # Only checks visited steps (steps with data).
        # Returns nil if all visited steps are valid.
        #
        # Useful for:
        # - Displaying which step has errors
        # - Redirecting to problem step
        # - Error reporting
        #
        # @param target_step [Symbol, nil] End point for search (nil = full path)
        # @return [Symbol, nil] Step ID of first invalid step, or nil if all valid
        #
        # @example Found invalid step
        #   # Path: name (valid) -> email (invalid) -> review
        #   validator.first_invalid(target_step: :review)
        #   # => :email
        #
        # @example All valid
        #   # Path: name (valid) -> email (valid) -> review
        #   validator.first_invalid(target_step: :review)
        #   # => nil
        #
        # @example Unvisited steps ignored
        #   # Path: name (valid) -> email (unvisited) -> phone (invalid)
        #   # Only checks visited steps
        #   validator.first_invalid(target_step: :review)
        #   # => nil (email is unvisited, so skipped)
        #
        # @api public
        def first_invalid(target_step: nil)
          path = @wizard.path_traversal(target_step)
          path.find do |step_id|
            result = @step_validator.call(step_id)
            result.visited? && result.invalid?
          end
        end

        # Find first unvisited step in path
        #
        # Walks through path to find first step with no data.
        # Returns nil if all steps are visited.
        #
        # Useful for:
        # - Resuming wizard from incomplete point
        # - Finding where user left off
        # - Progress tracking
        #
        # @param target_step [Symbol, nil] End point for search (nil = full path)
        # @return [Symbol, nil] Step ID of first unvisited step, or nil if all visited
        #
        # @example Found unvisited step
        #   # Path: name (visited) -> email (unvisited) -> review
        #   validator.first_unvisited(target_step: :review)
        #   # => :email
        #
        # @example All visited
        #   # Path: name (visited) -> email (visited) -> review
        #   validator.first_unvisited(target_step: :review)
        #   # => nil
        #
        # @api public
        def first_unvisited(target_step: nil)
          path = @wizard.path_traversal(target_step)
          path.find { |step_id| !@step_validator.visited?(step_id) }
        end

        # Get summary statistics for path
        #
        # Returns counts and status flags for the path:
        # - total: total steps in path
        # - visited: how many steps have data
        # - valid: how many steps passed validation
        # - invalid: how many steps have errors
        # - unvisited: how many steps have no data
        # - complete: are all steps visited and valid?
        #
        # Useful for:
        # - Progress bars and indicators
        # - Status displays
        # - Logging and debugging
        #
        # @param target_step [Symbol, nil] End point for analysis (nil = full path)
        # @return [Hash]
        #
        # @example
        #   summary = validator.summary(target_step: :review)
        #   # => {
        #   #   total: 5,
        #   #   visited: 3,
        #   #   valid: 3,
        #   #   invalid: 0,
        #   #   unvisited: 2,
        #   #   complete: false
        #   # }
        #
        # @example Logging progress
        #   summary = validator.summary(target_step: :review)
        #   puts "Progress: #{summary[:visited]}/#{summary[:total]} steps"
        #   # Output: Progress: 3/5 steps
        #
        # @api public
        def summary(target_step: nil)
          results = call(target_step)

          {
            total: results.count,
            visited: results.count(&:visited?),
            valid: results.count(&:valid?),
            invalid: results.count(&:invalid?),
            unvisited: results.count(&:unvisited?),
            complete: results.all? { |r| r.visited? && r.valid? },
          }
        end

        # Get steps before target (not including target itself)
        #
        # @param target_step [Symbol]
        # @return [Array<Symbol>]
        #
        # @api private
        def steps_before(target_step)
          path = @wizard.path_traversal(target_step)
          return [] unless path.include?(target_step)

          idx = path.index(target_step)
          path[0...idx]
        end
      end
    end
  end
end
