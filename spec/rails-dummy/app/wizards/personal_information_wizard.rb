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

  def needs_permission_to_work_or_study?(data)
    nationalities = data.dig(:steps, :nationality, :nationalities)

    !nationalities.intersect?(%w[British Irish])
  end
end
