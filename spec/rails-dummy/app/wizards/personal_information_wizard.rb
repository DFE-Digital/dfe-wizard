class PersonalInformationWizard < DfE::Wizard::Base
  def steps_mapping
    [
      { name_and_date_of_birth: Steps::NameAndDateOfBirth },
      { nationality: Steps::Nationality },
      { right_to_work_or_study: Steps::RightToWorkOrStudy },
      { immigration_status: Steps::ImmigrationStatus },
      { review: Steps::Review },
    ]
  end

  def steps_processor
    DfE::Wizard::Steps::Graph.draw(self) do |graph|
      graph.start :name_and_date_of_birth
      graph.add_edge :name_and_date_of_birth, to: :nationality

      graph.add_branch(
        :nationality,
        when: :needs_permission_to_work_or_study?,
        then: :right_to_work_or_study,
        else: :review,
        label: 'Non-UK/Irish',
      )

      graph.add_branch(
        :right_to_work_or_study,
        when: lambda { |data|
          data.dig(:steps, :right_to_work_or_study, :right_to_work_or_study) == 'yes'
        },
        then: :immigration_status,
        else: :review,
        label: 'Right to work or study?',
      )

      graph.add_edge :immigration_status, to: :review
    end
  end

  def route_strategy
    DfE::Wizard::RouteStrategy::NamedRoutes.new(
      namespace: 'personal-information',
    )
  end

  def logger
    DfE::Wizard::Logger.new(ActiveSupport::Logger.new(STDOUT)) if Rails.env.local?
  end

  def needs_permission_to_work_or_study?(data)
    nationalities = data.dig(:steps, :nationality, :nationalities)

    !nationalities.intersect?(%w[British Irish])
  end
end
