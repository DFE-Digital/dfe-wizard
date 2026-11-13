module DfE
  module Wizard
    module Operations
      # Keeps the review navigation of a change from check answers
      #
      # Runs after Persist on every step of a wizard with
      # {Behaviours::CheckYourAnswers#review_navigation? review_navigation?}
      # on, unless the step lists its operations with `use:`. During a change
      # it records the step for Back links, starting afresh on the step whose
      # Change link was followed. On every save of a step on the path, in a
      # change or not, it clears the answers of steps the save took off the
      # path ({Behaviours::StateManagement#clear_off_path_answers?}).
      #
      # It does nothing for the check answers step itself, or in a wizard
      # without one. It never returns a failure.
      #
      # @example Listed by hand on a step with its own operations
      #   builder.on_step(:subject, use: [Validate, Persist, ReviewNavigation])
      #
      # @api public
      class ReviewNavigation
        # @param repository [Object] The wizard's repository
        # @param step [DfE::Wizard::Step] The saved step, built by the wizard
        def initialize(repository:, step:)
          @repository = repository
          @step = step
        end

        # @return [Hash] Always `{ success: true }`
        def execute
          wizard = @step.wizard
          return { success: true } unless wizard && review_step?(wizard)

          if wizard.return_to_review?
            wizard.clear_review if @step.step_id.to_s == wizard.return_to_review.to_s
            wizard.track_review_step
          end
          wizard.clear_off_path_answers if wizard.clear_off_path_answers?

          { success: true }
        end

        # Nothing to undo
        #
        # @return [void]
        def rollback; end

        private

        def review_step?(wizard)
          check_answers_step = wizard.check_answers_step
          !check_answers_step.nil? && @step.step_id.to_s != check_answers_step.to_s
        end
      end
    end
  end
end
