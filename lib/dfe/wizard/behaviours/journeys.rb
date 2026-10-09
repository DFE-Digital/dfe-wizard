module DfE
  module Wizard
    module Behaviours
      # Change journeys from check answers, and edits of saved records.
      #
      # Turned on by `graph.check_answers` in a Graph wizard. A wizard that
      # does not declare it behaves as in 1.0.
      #
      # @api public
      module Journeys
        # The saved record of an edit, given to `new` as `record:`
        #
        # The gem itself never calls this method, so an app wizard that
        # already defines `record` keeps its own and stays a draft unless
        # built with `record:`.
        #
        # @return [Object, nil] nil on a draft
        def record
          @edit_record
        end

        # The wizard's changeset
        #
        # Memoised per wizard instance. Building it reads and writes nothing
        # for a wizard that neither edits nor declares graph.check_answers.
        # Otherwise the first call checks that the changeset matches the
        # request: it reads the store once and never walks the graph.
        #
        # @return [DfE::Wizard::Changeset]
        # @raise [ChangesetExpired] built with `record:` and the changeset
        #   holds no edit
        # @raise [ChangesetMismatch] the changeset is an edit of another
        #   record, or an edit and the request has no `record:`
        def changeset
          @changeset ||= Changeset.new(self).tap do |built|
            built.check_mode!(@edit_record) if editing? || journeys?
          end
        end

        # Whether this request edits a saved record (built with `record:`)
        #
        # @return [Boolean]
        def editing?
          !@edit_record.nil?
        end

        # The mapper that seeds an edit from the saved record
        #
        # Override it to edit saved records. It must respond to
        # `to_answers(record)`.
        #
        # @return [#to_answers, nil] nil by default
        def mapper
          nil
        end

        # Start an edit of the saved record
        #
        # Call it at the edit entry point, on a wizard built with `record:`
        # and a new state_key. It seeds the changeset with
        # `mapper.to_answers(record)`, keeps the record's `updated_at`, its
        # identity and the caller URL, and starts a change journey for the
        # unit. Redirect to the step it returns.
        #
        # @param unit [Symbol] a unit id (a sub-wizard id or a step id). A
        #   step id on the path opens the edit on that step.
        # @param caller [String] the URL to return to when the edit ends
        # @return [Symbol] the first step to show
        # @raise [ArgumentError] without `record:`, `graph.check_answers`, a
        #   mapper or an `on_commit` operation; for an unknown unit; or for a
        #   repository that cannot hold a changeset
        # @raise [NotCallable] when the unit has no step on the path
        #
        # @example
        #   wizard = CourseWizard.new(state_store:, record: course)
        #   step = wizard.start_edit(unit: :funding_type, caller: course_path)
        #   redirect_to wizard.resolve_step_path(step)
        def start_edit(unit:, caller:)
          raise ArgumentError, 'start_edit needs a wizard built with record:' unless editing?
          raise ArgumentError, 'edits need graph.check_answers' unless journeys?
          raise ArgumentError, 'edits need a mapper' if mapper.nil?
          raise ArgumentError, 'edits need builder.on_commit' if steps_operator.commit_operations.empty?

          @changeset ||= Changeset.new(self)
          journey.start_edit(unit_id: unit.to_sym, caller_url: caller, record: @edit_record)
        end

        # The current answers for the steps on the full path
        #
        # Step attributes only, with their raw values, in attribute_names
        # order. Answers for steps that left the path are not included.
        #
        # @return [Hash{Symbol => Object}]
        def answers_on_path
          definitions = step_definitions
          on_path = full_path.each_with_object(Set.new) do |step_id, names|
            step_class = definitions[step_id]
            names.merge(step_class.attribute_names.map(&:to_sym)) if step_class.respond_to?(:attribute_names)
          end
          read = state_store.read

          cached_steps_processor.answer_owners.each_key.with_object({}) do |name, answers|
            next unless on_path.include?(name)

            if read.key?(name)
              answers[name] = read[name]
            elsif read.key?(name.to_s)
              answers[name] = read[name.to_s]
            end
          end
        end

        # Whether a step may be shown or saved in this request
        #
        # Always true on a draft. In an edit, true when the step is on the
        # path and in the journey's current unit or a unit it has shown.
        #
        # @param step_id [Symbol]
        # @return [Boolean]
        #
        # @example Guard a GET in an edit
        #   redirect_to wizard.resolve_step_path(wizard.redirect_step) unless wizard.step_accessible?(step)
        def step_accessible?(step_id)
          return true unless editing?

          journey.shows?(step_id.to_sym)
        end

        # Where to send a request for a step that is not accessible
        #
        # @return [Symbol, nil] the first step of the journey's current unit
        #   on the path (the step the journey opened on, for its unit), or nil
        #   when there is no journey
        def redirect_step
          journey.current_unit_first_step
        end

        # Save the current step (see StateManagement#save_current_step)
        #
        # In a change journey, a save that ends a unit moves the journey on.
        #
        # @return [Boolean] true if all operations succeeded, false if any failed
        # @raise [StepNotAccessible] in an edit, for a step the edit does not show
        def save_current_step
          if editing? && !step_accessible?(current_step_name)
            raise StepNotAccessible, "step #{current_step_name.inspect} is not shown in this edit"
          end
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

          journey_step(target).tap { |step| log_next_step_transition(from: current_step_name, to: step) }
        end

        # The previous step; nil when Back leaves an edit for its caller
        #
        # In a change journey, the journey picks the step before any
        # before_previous_step callback, as for #next_step.
        #
        # @return [Symbol, nil]
        def previous_step
          target = journey.back_target if journeys?
          return super if target.nil?

          journey_step(target).tap do |step|
            log_previous_step_transition(current: current_step_name, previous: step)
          end
        end

        # The previous step's path; the caller URL when Back leaves an edit
        #
        # @return [String, nil]
        def previous_step_path(fallback: nil, **options)
          return changeset.caller_url if editing? && journeys? && journey.back_target == Journey::CALLER

          super
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
          return if !journeys? || editing?

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

        # A journey target as a step. The caller is the check answers node
        # on a draft, and nil in an edit: its caller is a URL, which
        # previous_step_path returns.
        def journey_step(target)
          return target unless target == Journey::CALLER

          cached_steps_processor.check_answers_step unless editing?
        end
      end
    end
  end
end
