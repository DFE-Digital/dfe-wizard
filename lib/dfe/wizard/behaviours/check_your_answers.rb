module DfE
  module Wizard
    module Behaviours
      # Check-your-answers pattern support
      #
      # Implements the standard "check your answers" / review page pattern where:
      # 1. User can click "Change" next to any previous answer
      # 2. User is taken to that step with return_to parameter
      # 3. After editing, user is returned to review if path is complete and valid
      # 4. Back button navigates through visited history
      #
      # Use these methods as callbacks in your graph:
      #
      #   graph.before_next_step { handle_return_to_check_your_answers(:review) }
      #   graph.before_previous_step { handle_back_in_check_your_answers(:review, return_origin) }
      #
      # Review navigation (needs `graph.check_answers`) takes the user only to the
      # steps that need an answer after a change, then back to check answers:
      #
      #   graph.check_answers :check_answers, Steps::CheckAnswers
      #   graph.before_next_step { next_step_in_review if return_to_review }
      #   graph.before_previous_step { previous_step_in_review(return_to_review) }
      #
      # @api public
      module CheckYourAnswers
        # Return to check-your-answers if path is complete and valid
        #
        # Use as a callback in {StepsProcessor::Graph#before_next_step}.
        #
        # When user clicks "Continue" after editing a previous step:
        # 1. Checks if path to target is fully visited (all steps have data)
        # 2. Checks if path to target is valid (all data passes validation)
        # 3. Returns target step to redirect back to review
        # 4. Returns nil to fall through and continue forward through graph
        #
        # Returns nil (falls through) if:
        # - User hasn't visited all required steps
        # - Some steps have validation errors
        # - Conditional branching requires more steps to complete
        #
        # @param target_step [Symbol] The check-your-answers step (usually :review)
        # @return [Symbol, nil] target_step if ready to return, nil to continue forward
        #
        # @example Return to review after editing
        #   # Graph callback:
        #   graph.before_next_step { handle_return_to_check_your_answers(:review) }
        #
        #   # URL: /email?return_to_review=review
        #   # User was at: name -> email -> review
        #   # User clicks "Change" on email
        #   # User edits email and clicks "Continue"
        #
        #   wizard.handle_return_to_check_your_answers(:review)
        #   # Path is complete and valid
        #   # => :review  (redirects back to review page)
        #
        # @example Can't return because path incomplete
        #   # User was at: name -> (conditional) -> email -> review
        #   # User clicked "Change" on email
        #   # Conditional changed - now requires extra step before email
        #
        #   wizard.handle_return_to_check_your_answers(:review)
        #   # Path now requires more steps
        #   # => nil  (falls through to normal navigation)
        def handle_return_to_check_your_answers(target_step = check_answers_step)
          target_step if valid_path_to?(target_step)
        end

        # Navigate back through visited steps in edit mode
        #
        # Use as a callback in {StepsProcessor::Graph#before_previous_step}.
        #
        # When user clicks back link while editing a previous step:
        # 1. If at the step they clicked "Change" from → return to review
        # 2. Otherwise → walk backward through visited steps
        #
        # Returns nil (falls through) to use default graph navigation.
        #
        # @param target_step [Symbol] The check-your-answers step (usually :review)
        # @param origin_step [Symbol] The step user clicked "Change" on
        # @return [Symbol, nil] Previous step, or nil to use default graph navigation
        #
        # @example At origin step - go back to review
        #   # URL: /email?return_to_review=email
        #   # current_step = :email
        #   # origin_step = :email (where user clicked "Change")
        #
        #   wizard.handle_back_in_check_your_answers(:review, :email)
        #   # => :review  (back to check-your-answers)
        #
        # @example Not at origin - walk through history
        #   # User was at: name -> email -> phone -> review
        #   # Clicked "Change" on email
        #   # Added a step between: name -> email -> address -> phone
        #   # Went: email -> address -> phone
        #   # Now on :phone and clicks back
        #
        #   wizard.handle_back_in_check_your_answers(:review, :email)
        #   # => :address  (walk backward through visited steps)
        #
        # @example Last visited - go back to review
        #   # Been to: email -> review (review has no data to edit)
        #   # Clicked "Change" on email
        #   # Edited email, clicked "Continue" back to review
        #   # Now on review, clicks back
        #   # current_step = :review, but :review has origin_step param
        #
        #   wizard.handle_back_in_check_your_answers(:review, :email)
        #   # current_step != origin_step, so walk backward
        #   # => :email  (last visited step before review)
        def handle_back_in_check_your_answers(target_step, origin_step)
          # If at the step user originally clicked "Change" on, return to review
          target_step if current_step_name.to_s == origin_step.to_s
        end

        # Next step after a change from check answers
        #
        # Looks at the steps ahead of the current one on the path to check
        # answers, over the current answers, and returns the first that needs
        # an answer: blank, or not valid. When none does, returns `finish`.
        #
        # Steps that are still valid are skipped, so a change only shows the
        # questions it affects: a step that is new on the path, or whose answer
        # the change made invalid. A step whose valid options depend on an
        # earlier answer must validate against the current branch for this to
        # work.
        #
        # It only reads state, so it is safe in a `before_next_step` callback.
        #
        # @param finish [Symbol] Where to go when nothing ahead needs an answer
        #   (defaults to the check answers step). An edit of a saved record can
        #   finish on a confirm step or a Redirect node instead.
        # @param only [Array<Symbol>, nil] When given, only these steps can be
        #   shown. Useful for an edit that seeds just some of the answers.
        # @return [Symbol] Step to go to next
        # @raise [ArgumentError] If the graph declares no check answers step
        #
        # @example In the graph
        #   graph.check_answers :check_answers, Steps::CheckAnswers
        #   graph.before_next_step { next_step_in_review if return_to_review }
        #
        # @example Funding changed from fee to salary
        #   # path ahead: study_pattern (valid), skilled_worker_visa (blank), start_date (valid)
        #   wizard.next_step_in_review  # => :skilled_worker_visa
        #
        # @example An edit of a saved course that finishes on a confirm page
        #   wizard.next_step_in_review(finish: :confirm_changes, only: %i[funding_type skilled_worker_visa])
        #
        # @api public
        def next_step_in_review(finish: check_answers_step, only: nil)
          review_step = required_check_answers_step
          ahead = flow_path(review_step, from: current_step_name).drop(1) - [review_step]
          ahead &= only.map(&:to_sym) if only

          ahead.find { |step_id| !valid?(step_id) } || finish
        end

        # Previous step during a change from check answers
        #
        # Retraces the steps shown since the user followed the Change link:
        # the nearest earlier step on the path that is the origin step or was
        # recorded with {#track_review_step}. On the origin step itself it
        # returns `finish`, so Back goes to check answers.
        #
        # @param origin_step [Symbol, String, nil] The step whose Change link the
        #   user followed (usually the `return_to_review` param). When blank or
        #   not a String or Symbol (e.g. a tampered array param), returns nil so
        #   a `before_previous_step` callback falls through.
        # @param finish [Symbol] Where Back goes from the origin step (defaults
        #   to the check answers step)
        # @return [Symbol, nil] Step to go back to, or nil when there is no origin step
        #
        # @example In the graph
        #   graph.before_previous_step { previous_step_in_review(return_to_review) }
        #
        # @example After funding_type → skilled_worker_visa → deadline_required
        #   wizard.previous_step_in_review(:funding_type)  # on deadline_required
        #   # => :skilled_worker_visa
        #
        # @api public
        def previous_step_in_review(origin_step, finish: check_answers_step)
          return unless origin_step.is_a?(String) || origin_step.is_a?(Symbol)
          return if origin_step.blank?

          origin = origin_step.to_sym
          return finish if current_step_name == origin

          shown = review_shown
          earlier = flow_path(current_step_name, from: origin)[0...-1]
          earlier.reverse.find { |step_id| step_id == origin || shown.include?(step_id) } || finish
        end

        # Record the current step as shown during a change from check answers
        #
        # Call it after the step saves, while a change is in progress. Back
        # links ({#previous_step_in_review}) retrace the recorded steps.
        # Kept in the wizard metadata under `:review_shown`.
        #
        # @return [void]
        #
        # @example In the controller
        #   if @wizard.save_current_step
        #     @wizard.track_review_step if params[:return_to_review].present?
        #     redirect_to @wizard.next_step_path(...)
        #   end
        #
        # @api public
        def track_review_step
          set_metadata(:review_shown, (review_shown | [current_step_name]).map(&:to_s))
        end

        # Steps recorded with {#track_review_step} since the last {#clear_review}
        #
        # @return [Array<Symbol>]
        #
        # @api public
        def review_shown
          Array(get_metadata(:review_shown)).map(&:to_sym)
        end

        # Forget the steps shown in a change
        #
        # Call it when the user is back on check answers, so the next change
        # starts afresh.
        #
        # @return [void]
        #
        # @example In the check answers action
        #   @wizard.clear_review
        #
        # @api public
        def clear_review
          set_metadata(:review_shown, [])
        end

        # Find previous visited step in path
        #
        # Walks backward from current position through the path to target,
        # returning the first step that has been visited.
        #
        # Used by {#handle_back_in_check_your_answers} to navigate backwards.
        #
        # @param target_step [Symbol] The end point for backward search
        # @return [Symbol, nil] Previous visited step, or nil if at start
        #
        # @example
        #   # Path: name -> email -> address -> phone -> review
        #   # Current: phone
        #   # Visited: name, email, address, phone
        #
        #   wizard.previous_visited_step_in_path(:review)
        #   # => :address (previous visited step)
        #
        # @example At start of path
        #   # Path: name -> ...
        #   # Current: name (first step)
        #
        #   wizard.previous_visited_step_in_path(:review)
        #   # => nil (nowhere to go back to)
        #
        # @api private
        def previous_visited_step_in_path(target_step)
          path = flow_path(target_step)
          idx = path.index(current_step_name)
          return nil unless idx&.positive?

          path[0...idx].reverse.find { |step_id| saved?(step_id) }
        end

        private

        def required_check_answers_step
          check_answers_step || raise(ArgumentError, 'Declare the check answers step with graph.check_answers')
        end
      end
    end
  end
end
