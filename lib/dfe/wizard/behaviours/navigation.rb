module DfE
  module Wizard
    module Behaviours
      # Navigation through wizard steps
      #
      # Manages step traversal, paths, and direction based on:
      # - Step processor (graph structure & branching)
      # - Current wizard state (user data)
      #
      # Provides two types of APIs:
      # 1. Step navigation: next_step, previous_step, *_step_path
      # 2. Flow paths: flow_path, in_flow? (graph-based)
      #
      # @api public
      module Navigation
        # Calculate the next step
        #
        # @return [Symbol, nil] Next step ID, or nil if at end
        #
        # @example
        #   wizard.next_step  # => :email
        def next_step
          steps_processor.next_step(current_step_name).tap do |next_step_id|
            log_next_step_transition(from: current_step_name, to: next_step_id)
          end
        end

        # Calculate the previous step
        #
        # @return [Symbol, nil] Previous step ID, or nil if at root
        #
        # @example
        #   wizard.previous_step  # => :name
        def previous_step
          steps_processor.previous_step(current_step_name).tap do |previous_step_id|
            log_previous_step_transition(current: current_step_name, previous: previous_step_id)
          end
        end

        # URL/path for the current step
        #
        # @param options [Hash] Additional routing options
        # @return [String]
        #
        # @example
        #   wizard.current_step_path  # => "/wizard/name"
        def current_step_path(options = {})
          resolve_step_path(current_step_name, options)
        end

        # URL/path for the next step
        #
        # @param options [Hash] Additional routing options
        # @return [String, nil]
        #
        # @example
        #   wizard.next_step_path  # => "/wizard/email"
        def next_step_path(options = {})
          resolve_step_path(next_step, options)
        end

        # URL/path for the previous step
        #
        # @param fallback [String, nil] URL if no previous step exists
        # @param options [Hash] Additional routing options
        # @return [String, nil]
        #
        # @example
        #   wizard.previous_step_path  # => "/wizard/name"
        #   wizard.previous_step_path(fallback: "/")  # => "/" if no previous
        def previous_step_path(fallback: nil, **options)
          step = previous_step
          return fallback unless step && step != current_step_name

          resolve_step_path(step, options)
        end

        # Resolves URL/path for a step using the route strategy
        #
        # @param step_id [Symbol] The step to resolve
        # @param options [Hash] Additional routing options
        # @return [String]
        #
        # @api private
        def resolve_step_path(step_id, options = {})
          route_strategy.resolve(step_id:, options:).tap do |path|
            log_route_resolved(step: step_id, path:)
          end
        end

        # Flow path: steps in current wizard flow
        #
        # Returns the sequence of steps user will traverse based on:
        # - Step processor graph structure
        # - Current user data (for conditional branching only)
        #
        # This is the "theoretical" path for this user, regardless of
        # whether they've completed steps or if data is valid.
        #
        # @return [Array<Symbol>] Sequence of steps in flow
        #
        # @example UK national
        #   wizard.flow_path  # => [:name, :nationality, :review]
        #
        # @example Non-UK national
        #   wizard.flow_path  # => [:name, :nationality, :right_to_work, :immigration_status, :review]
        def flow_path(target = current_step_name)
          steps_processor.path_traversal(target).tap do |path|
            log_flow_path_resolved(target:, path:)
          end
        end

        # Check if step is in current flow
        #
        # @param step_id [Symbol] Step to check
        # @return [Boolean] true if step will appear in flow
        #
        # @example
        #   wizard.in_flow?(:email)           # => true
        #   wizard.in_flow?(:skipped_step)    # => false
        def in_flow?(step_id)
          flow_path(step_id).include?(step_id)
        end
      end
    end
  end
end
