module DfE
  module Wizard
    # Change journey navigation for a wizard that declares
    # `graph.check_answers`.
    #
    # A journey starts on the GET that carries `return_to_review=<step_id>`
    # (#start_redirect), or, for an edit of a saved record, in #start_edit.
    # It opens on the step it names (the entry step) and shows the rest of
    # that step's unit, then each later unit on the path whose `depends_on`
    # names an answer that changed since the start, then returns to the
    # caller: the check answers node on a draft, the caller URL in an edit.
    #
    # State changes only in #start_redirect, #start_edit and #after_save.
    # #next_target and #back_target, which Behaviours::Journeys resolves
    # before 1.0 navigation, read state and never write.
    #
    # Stored state (in the changeset, under :journey):
    # - unit: the unit being shown;
    # - shown: units already shown in this journey, in order;
    # - snapshot: the answers at the start;
    # - entry: the entry step, the step the journey opened on.
    #
    # A unit's journey steps are its steps on the path. For the unit of the
    # entry step they start at the entry step: the steps before it are
    # outside the journey.
    #
    # @api private
    class Journey
      START_PARAM = :return_to_review

      # Target meaning "the caller": the check answers node on a draft, a
      # URL in an edit
      CALLER = :_dfe_wizard_caller

      # @param wizard [DfE::Wizard]
      # @param graph [StepsProcessor::Graph] the wizard's cached graph
      def initialize(wizard, graph:)
        @wizard = wizard
        @graph = graph
        @finished = false
      end

      # Start a journey from the start param
      #
      # Every start restarts the journey: the old state is replaced.
      #
      # @param step_id [Symbol] the value of the start param
      # @return [String, nil] the path to redirect to, or nil when the step
      #   is in no unit
      def start_redirect(step_id)
        unit = graph.unit_for(step_id)
        return unless unit

        first_step = begin_journey(unit, step_id)
        changeset.journey = nil unless first_step
        @wizard.resolve_step_path(first_step || graph.check_answers_step)
      end

      # Start the journey of an edit of a saved record
      #
      # Seeds the changeset from the record and the wizard's mapper, stores
      # the record identity and the caller URL, then starts a journey for
      # the unit.
      #
      # @param unit_id [Symbol] a unit id, or a step id in the unit. A step
      #   id on the path is the entry step.
      # @param caller_url [String]
      # @param record [Object] the record given to the wizard's `new`
      # @return [Symbol] the entry step
      # @raise [ArgumentError] for an unknown unit
      # @raise [NotCallable] when the unit has no step on the path
      def start_edit(unit_id:, caller_url:, record:)
        unit = graph.unit(unit_id)
        raise ArgumentError, "#{unit_id.inspect} is not a unit or a step" unless unit

        changeset.seed!(@wizard.mapper.to_answers(record), updated_at: record.updated_at)
        changeset.identify!(record:, caller_url:)

        first_step = begin_journey(unit, unit_id)
        unless first_step
          changeset.discard!
          raise NotCallable, "unit #{unit.id.inspect} has no step on the path for this record"
        end

        first_step
      end

      # Whether the save in this request ended the journey
      #
      # @return [Boolean]
      def finished?
        @finished
      end

      # Whether the journey shows a step: the step is a journey step of the
      # current unit or of a shown unit. The check answers node is
      # never shown.
      #
      # @param step_id [Symbol]
      # @return [Boolean]
      def shows?(step_id)
        state = journey_state
        unit = graph.unit_for(step_id)
        return false unless state && unit

        units = [state[:unit]] + state[:shown]
        units.include?(unit.id) && journey_steps(@wizard.full_path, unit, state).include?(step_id)
      end

      # The first journey step of the current unit
      #
      # @return [Symbol, nil] nil when there is no journey
      def current_unit_first_step
        state = journey_state
        return unless state

        journey_steps(@wizard.full_path, graph.unit(state[:unit]), state).first
      end

      # Called by save_current_step after the step's operations succeed
      #
      # - A save on a step outside the journey changes nothing; navigation
      #   is as in 1.0. A step of the entry step's unit before the entry
      #   step is outside the journey.
      # - A save in a unit already shown (the user went Back into it) makes
      #   that unit current again, and forgets it and every later shown unit.
      # - A save on the unit's last journey step ends the unit: the
      #   next unit is the first later unit on the path, not yet shown, whose
      #   depends_on names a changed answer. With none, the journey ends.
      #
      # @return [void]
      def after_save
        state = journey_state
        unit = current_unit
        return unless state && unit

        shown = state[:shown]
        if shown.include?(unit.id)
          shown = shown.take(shown.index(unit.id))
        elsif unit.id != state[:unit]
          return
        end

        path = @wizard.full_path
        steps = journey_steps(path, unit, state)
        return unless steps.include?(current_step_name)

        if later_step(steps)
          changeset.journey = state.merge(unit: unit.id, shown:)
          return
        end

        shown += [unit.id]
        next_unit = queued_units(path, unit, shown, changeset.answer_changes_since(state[:snapshot])).first
        if next_unit
          changeset.journey = state.merge(unit: next_unit.id, shown:)
        else
          # An edit keeps the state until the commit discards the changeset,
          # so an operation that raises leaves the edit where it was.
          changeset.journey = nil unless @wizard.editing?
          @finished = true
        end
      end

      # The step after the current one in the journey
      #
      # @return [Symbol, nil] a step id, CALLER once this request's save
      #   ended the journey, or nil to use 1.0 navigation
      def next_target
        return CALLER if @finished

        state = journey_state
        unit = current_unit
        return unless state && unit

        path = @wizard.full_path
        steps = journey_steps(path, unit, state)
        return unless steps.include?(current_step_name)
        return later_step(steps) if unit.id == state[:unit]
        return unless state[:shown].include?(unit.id)

        journey_steps(path, graph.unit(state[:unit]), state).first
      end

      # The Back target in the journey
      #
      # Inside a unit, Back goes to the previous journey step of the unit.
      # On its first journey step, Back goes to the last step of the unit
      # shown before it, and on the entry step to the caller.
      #
      # @return [Symbol, nil] a step id, CALLER, or nil to use 1.0 navigation
      def back_target
        state = journey_state
        unit = current_unit
        return unless state && unit

        shown = state[:shown]
        active = unit.id == state[:unit]
        return unless active || shown.include?(unit.id)

        path = @wizard.full_path
        steps = journey_steps(path, unit, state)
        index = steps.index(current_step_name)
        return unless index
        return steps[index - 1] if index.positive?

        earlier = shown.include?(unit.id) ? shown.take(shown.index(unit.id)) : shown
        last_shown_step(path, earlier)
      end

      private

      # The last step on the path of the last of the units that has one,
      # or CALLER
      def last_shown_step(path, unit_ids)
        unit_ids.reverse_each do |unit_id|
          last_step = unit_steps_on(path, graph.unit(unit_id)).last
          return last_step if last_step
        end

        CALLER
      end

      # Writes a new journey state for the unit when it has a step on the
      # path, and returns the entry step: step_id when it is one of the
      # unit's steps on the path, and otherwise the unit's first
      def begin_journey(unit, step_id)
        steps = unit_steps_on(@wizard.full_path, unit)
        entry = steps.include?(step_id) ? step_id : steps.first
        changeset.journey = { unit: unit.id, shown: [], snapshot: changeset.answers, entry: } if entry
        entry
      end

      # The stored journey state with unit, shown and entry as symbols, or nil
      def journey_state
        state = changeset.journey
        return unless state

        state.merge(
          unit: state[:unit].to_sym,
          shown: Array(state[:shown]).map(&:to_sym),
          entry: state[:entry]&.to_sym,
        )
      end

      def current_unit
        graph.unit_for(current_step_name)
      end

      def current_step_name
        @wizard.current_step_name
      end

      def unit_steps_on(path, unit)
        return [] unless unit

        path.select { |step_id| unit.step_ids.include?(step_id) }
      end

      # The unit's journey steps: its steps on the path, from the entry step
      # for the unit of the entry step. All its steps on the path when the
      # entry step is not on the path.
      def journey_steps(path, unit, state)
        steps = unit_steps_on(path, unit)
        index = steps.index(state[:entry])
        index ? steps.drop(index) : steps
      end

      def later_step(steps)
        index = steps.index(current_step_name)
        index ? steps[index + 1] : nil
      end

      def queued_units(path, unit, shown, changed)
        units = path.filter_map { |step_id| graph.unit_for(step_id) }.uniq(&:id)
        units.drop_while { |candidate| candidate.id != unit.id }.drop(1).select do |candidate|
          !shown.include?(candidate.id) && candidate.depends_on.intersect?(changed)
        end
      end

      def changeset
        @wizard.changeset
      end

      attr_reader :graph
    end
  end
end
