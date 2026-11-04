module DfE
  module Wizard
    module Behaviours
      # Change journeys from check answers.
      #
      # Turned on by `graph.check_answers` in a Graph wizard. A wizard that
      # does not declare it behaves as in 1.0.
      #
      # @api public
      module Journeys
        # The wizard's changeset
        #
        # Memoised per wizard instance. Building it reads and writes nothing.
        #
        # @return [DfE::Wizard::Changeset]
        def changeset
          @changeset ||= Changeset.new(self)
        end

        # Save the current step (see StateManagement#save_current_step)
        #
        # In a change journey, a save that ends a unit moves the journey on.
        #
        # @return [Boolean] true if all operations succeeded, false if any failed
        def save_current_step
          return false unless super

          journey.after_save if journeys?
          true
        end

        # The next step
        #
        # In a change journey, the journey picks the step before any
        # before_next_step callback or edge, so a callback cannot override
        # it.
        #
        # @return [Symbol, nil]
        def next_step
          target = journey.next_target if journeys?
          return super if target.nil?

          target.tap { |step| log_next_step_transition(from: current_step_name, to: step) }
        end

        # The previous step
        #
        # In a change journey, the journey picks the step before any
        # before_previous_step callback, as for #next_step.
        #
        # @return [Symbol, nil]
        def previous_step
          target = journey.back_target if journeys?
          return super if target.nil?

          target.tap do |step|
            log_previous_step_transition(current: current_step_name, previous: step)
          end
        end

        # Start a change journey on a GET that carries the start param
        #
        # Call it at the top of the step's GET action. When the request
        # carries `return_to_review=<step_id>` and the wizard declares
        # `graph.check_answers`, it starts (or restarts) the journey for the
        # step's unit and returns the path of the step, without the param.
        # When the step is not on the path, it returns the path of the unit's
        # first step on the path. Redirect to it.
        #
        # @return [String, nil] the path to redirect to, or nil
        # @raise [ArgumentError] when the repository cannot hold a changeset
        #
        # @example
        #   def show
        #     redirect = @wizard.journey_start_redirect
        #     redirect_to(redirect) if redirect
        #   end
        def journey_start_redirect
          return unless journeys?

          step_id = journey_start_param
          journey.start_redirect(step_id) if step_id
        end

        # Whether the wizard declares graph.check_answers
        #
        # @return [Boolean]
        def journeys?
          !cached_steps_processor.check_answers_step.nil?
        end

        # @return [DfE::Wizard::Journey]
        # @api private
        def journey
          @journey ||= Journey.new(self, graph: cached_steps_processor)
        end

        private

        # The start param of the params the wizard was built with, unfiltered
        def journey_start_param
          params = @current_step_params
          return unless params.respond_to?(:[])

          value = params[Journey::START_PARAM] || params[Journey::START_PARAM.to_s]
          value.presence&.to_sym
        end
      end
    end
  end
end
