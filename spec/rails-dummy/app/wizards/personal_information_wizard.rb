class PersonalInformationWizard
  include DfE::Wizard

  def steps_processor
    DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
      graph.add_node :name_and_date_of_birth, Steps::NameAndDateOfBirth
      graph.add_node :nationality, Steps::Nationality
      graph.add_node :right_to_work_or_study, Steps::RightToWorkOrStudy
      graph.add_node :immigration_status, Steps::ImmigrationStatus
      graph.add_node :review, Steps::Review

      graph.root :name_and_date_of_birth
      graph.add_edge from: :name_and_date_of_birth, to: :nationality

      graph.add_conditional_edge(
        from: :nationality,
        when: :needs_permission_to_work_or_study?,
        then: :right_to_work_or_study,
        else: :review,
        label: 'Non-UK/Non-Irish',
      )

      graph.add_conditional_edge(
        from: :right_to_work_or_study,
        when: ->(step, _) { step.right_to_work_or_study? },
        then: :immigration_status,
        else: :review,
        label: 'Right to work or study?',
      )

      graph.add_edge from: :immigration_status, to: :review

      graph.before_next_step(:next_step_before_callback)
      graph.before_previous_step(:previous_step_before_callback)
    end
  end

  def route_strategy
    DfE::Wizard::RouteStrategy::NamedRoutes.new(
      namespace: 'personal-information',
    )
  end

  def logger; end

  def next_step_before_callback
    handle_return_to_check_your_answers(:review) if return_to_review?
  end

  def previous_step_before_callback
    handle_back_in_check_your_answers(:review, return_to_review) if return_to_review?
  end

  def return_to_review?
    return_to_review.present?
  end

  def return_to_review
    step_params[:return_to_review]
  end

  def needs_permission_to_work_or_study?(step)
    step.needs_permission_to_work_or_study?
  end
end
