class ALevelsRequirementsWizard
  include DfE::Wizard

  attr_reader :course

  delegate :any_a_levels?,
           :add_another_a_level?,
           :has_remaining_a_levels?,
           to: :state_store

  def steps_processor
    DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
      graph.add_node :what_a_level_is_required, Steps::WhatALevelIsRequired
      graph.add_node :add_a_level_to_a_list, Steps::AddALevelToAList
      graph.add_node :remove_a_level_subject_confirmation, Steps::RemoveALevelSubjectConfirmation
      graph.add_node :consider_pending_a_level, Steps::ConsiderPendingALevel
      graph.add_node :a_level_equivalencies, Steps::ALevelEquivalencies
      graph.add_node :course_edit, DfE::Wizard::Redirect

      graph.conditional_root(potential_root: %i[add_a_level_to_a_list what_a_level_is_required]) do |state_store|
        if state_store.any_a_levels?
          :add_a_level_to_a_list
        else
          :what_a_level_is_required
        end
      end

      graph.add_edge from: :what_a_level_is_required, to: :add_a_level_to_a_list

      graph.add_conditional_edge(
        from: :add_a_level_to_a_list,
        when: :add_another_a_level?,
        then: :what_a_level_is_required,
        else: :consider_pending_a_level,
        label: 'Add another A-level?',
      )

      graph.add_edge from: :consider_pending_a_level, to: :a_level_equivalencies

      graph.add_conditional_edge(
        from: :remove_a_level_subject_confirmation,
        when: :has_remaining_a_levels?,
        then: :add_a_level_to_a_list,
        else: :course_edit,
        label: 'Has remaining A-levels?',
      )
    end
  end

  def route_strategy
    @route_strategy ||= DfE::Wizard::RouteStrategy::ConfigurableRoutes.new(
      wizard: self,
      namespace: 'a_levels_requirements',
    ) do |config|
      config.default_path_arguments = {
        provider_code: course.provider_code,
        recruitment_cycle_year: course.recruitment_cycle_year,
        course_code: course.course_code,
      }

      config.map_step :course_edit, to: lambda { |_wizard, options, helpers|
        helpers.publish_provider_recruitment_cycle_course_path(**options)
      }
    end
  end

  def logger
    @logger ||= DfE::Wizard::Logger.new(Rails.logger)
  end

  def inspect
    DfE::Wizard::Inspect.new(wizard: self) if Rails.env.local?
  end
end
