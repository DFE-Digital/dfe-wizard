# frozen_string_literal: true

module DfE
  module Wizard
    module Core
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
        def handle_return_to_check_your_answers(target_step)
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
      end
    end
  end
end
