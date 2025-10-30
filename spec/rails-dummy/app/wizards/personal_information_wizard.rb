class PersonalInformationWizard < DfE::Wizard::Base
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
        when: lambda { |data|
          data.dig(:steps, :right_to_work_or_study, :right_to_work_or_study) == 'yes'
        },
        then: :immigration_status,
        else: :review,
        label: 'Right to work or study?',
      )

      graph.add_edge from: :immigration_status, to: :review

      graph.before_next_step(:next_step_before_callback)
    end
  end

  def route_strategy
    DfE::Wizard::RouteStrategy::NamedRoutes.new(
      namespace: 'personal-information',
    )
  end

  def logger
    DfE::Wizard::Logger.new(Rails.logger) if Rails.env.local?
  end

  def next_step_before_callback
    target = step_params[:return_to_review]

    :review if target && path_traversal(:review).map(&:to_s).include?(target) && completed?
  end

  def previous_step_before_callback
    target = step_params[:return_to_review]

    :review if target &&
               path_traversal(:review).map(&:to_s).include?(target) &&
               current_step_name.to_s == target &&
               completed?
  end

  # if wizard is "complete" then the path traversal from the start to end
  # will include the review step
  #
  def completed?
    steps_processor.path_traversal(:review).include?(:review)
  end

  def needs_permission_to_work_or_study?(data)
    nationalities = data.dig(:steps, :nationality, :nationalities)

    !nationalities.intersect?(%w[british irish])
  end
end
