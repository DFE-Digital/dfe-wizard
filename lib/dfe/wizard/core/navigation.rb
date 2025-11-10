# frozen_string_literal: true

module DfE
  module Wizard
    module Core
      # Navigation through wizard steps
      #
      # Calculates next/previous steps and complete paths based on the
      # steps processor (graph) and current wizard state.
      #
      # @api public
      module Navigation
        # Calculate the next step
        #
        # Uses the steps processor to determine what step comes next
        # based on current state and wizard data.
        #
        # @return [Symbol, nil] The next step ID, or nil if at end
        #
        # @example
        #   wizard.next_step  # => :email
        def next_step
          steps_processor.next_step(current_step_name)
        end

        # Calculate the previous step
        #
        # Uses the steps processor to determine the previous step.
        # Returns nil if at the root step.
        #
        # @return [Symbol, nil] The previous step ID, or nil if at root
        #
        # @example
        #   wizard.previous_step  # => :name
        def previous_step
          steps_processor.previous_step(current_step_name)
        end

        # Returns the URL/path for the current step
        #
        # @param options [Hash] Any additional routing options
        # @return [String]
        def current_step_path(options = {})
          resolve_step_path(current_step_name, options)
        end

        # Returns the URL/path for the next step
        #
        # @param options [Hash]
        # @return [String, nil]
        def next_step_path(options = {})
          resolve_step_path(next_step, options)
        end

        # Returns the URL/path for the previous step. Can specify a fallback if not present.
        #
        # @param fallback [String, nil] Fallback URL if no previous step
        # @param options [Hash]
        # @return [String, nil]
        def previous_step_path(fallback: nil, **options)
          step = previous_step

          return fallback unless step && step != current_step_name

          resolve_step_path(step, options)
        end

        # Resolves a URL/path for a given step using the route strategy.
        #
        # @param step [Symbol]
        # @param options [Hash]
        # @return [String]
        def resolve_step_path(step_id, options = {})
          route_strategy.resolve(step_id:, options:)
        end

        # Calculate the complete path to a target step
        #
        # Returns the sequence of steps from root to target based on
        # current wizard state. Returns empty array if target unreachable.
        #
        # @param target_step [Symbol, nil] The target step (default: current path)
        # @return [Array<Symbol>] Sequence of steps in the path
        #
        # @example
        #   wizard.path_traversal(:review)  # => [:name, :email, :review]
        #   wizard.path_traversal  # => [:name, :email, :review] (to end)
        def path_traversal(target_step = nil)
          steps_processor.path_traversal(target_step)
        end

        # Check if a PATH EXISTS in the graph to reach a target step
        #
        # Only checks GRAPH REACHABILITY based on current data.
        #
        # Does NOT check:
        # - If steps are valid
        # - If steps have the right data
        #
        # This answers: "Given current data, is this step theoretically reachable?"
        #
        # Does NOT:
        # - Validate any steps
        # - Check if all previous steps are complete
        #
        # @param target_step [Symbol] The target step
        # @return [Boolean] true if step exists in reachable path
        #
        # @example Step is in graph path
        #   # Graph: name -> email -> review
        #   # Current data: not UK (so email is reachable)
        #   wizard.completed_to?(:email)  # => true
        #
        # @example Step is skipped by conditional logic
        #   # Graph: name -> (if UK: email) -> (if not UK: phone) -> review
        #   # Data: not UK
        #   # Email is in graph, but NOT in current path
        #
        #   wizard.completed_to?(:email)  # => false
        #   wizard.completed_to?(:phone)  # => true
        def completed_to?(target_step)
          path_traversal(target_step).include?(target_step)
        end

        # Return all steps as instantiated step objects for a path to the target
        # Creates an ordered list of instantiated step objects for the
        # relevant path—useful for rendering "Check your answers" summaries,
        # review screens, and full wizard navigation.
        #
        # It does NOT perform validation; it deals with the actual data and
        # how to turn that data into step objects, in wizard order.
        #
        # Used for rendering review/"check your answers" pages and
        # building navigation displays.
        #
        # @param target_step [Symbol, nil] Step to traverse to (default: end of wizard)
        # @return [Array<DfE::Wizard::Step>]
        #
        # @example
        #   steps = wizard.summary_steps(:review)
        #   steps.each { |step| puts step.step_id }  # :name, :email, :review
        def summary_steps(target_step = nil)
          path = path_traversal(target_step)

          path.map do |step_id|
            klass = find_step(step_id)
            step_data = read_step_data(step_id)
            klass.new(step_data.merge(wizard: self, step_id: step_id))
          end
        end
      end
    end
  end
end
