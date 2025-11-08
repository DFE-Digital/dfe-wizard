class GetFundingWizard
  include DfE::Wizard

  def steps_processor
    DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
      graph.add_node :personal_details, Steps::PersonalDetails
      graph.add_node :academic_background, Steps::AcademicBackground
      graph.add_node :get_funding, Steps::GetFunding
      graph.add_node :visa_requirement, Steps::VisaRequirement
      graph.add_node :additional_support, Steps::AdditionalSupport
      graph.add_node :review, Steps::Review

      graph.root :personal_details

      graph.add_edge from: :personal_details, to: :academic_background

      graph.add_conditional_edge(
        from: :academic_background,
        when: :needs_funding_options?,
        then: :get_funding,
        else: :visa_requirement,
        label: 'Needs funding?',
      )

      graph.add_custom_branching_edge(
        from: :visa_requirement,
        conditional: :visa_branching_logic,
        potential_transitions: [
          { label: 'Requires support', nodes: [:additional_support] },
          { label: 'Funding incomplete', nodes: [:get_funding] },
          { label: 'All done', nodes: [:review] },
        ],
      )

      graph.add_edge from: :additional_support, to: :review
      graph.add_edge from: :get_funding, to: :review
    end
  end

  def needs_funding_options?(data)
    data.dig(:steps, :academic_background, :needs_funding) == true
  end

  def visa_branching_logic(data)
    needs_support = data.dig(:steps, :visa_requirement, :needs_support)
    funding_complete = data.dig(:steps, :get_funding, :complete)

    if funding_complete == false
      :get_funding
    elsif needs_support
      :additional_support
    else
      :review
    end
  end
end
