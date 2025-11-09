class AssignMentorWizard
  include DfE::Wizard

  def steps_processor
    DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
      graph.add_node :who_will_be_the_mentor, Steps::WhoWillBeTheMentor
      graph.add_node :can_receive_mentor_training, Steps::CanReceiveMentorTraining
      graph.add_node :which_lead_provider, Steps::WhichLeadProvider
      graph.add_node :confirmation, Steps::Confirmation

      graph.root :who_will_be_the_mentor
      graph.add_edge from: :who_will_be_the_mentor, to: :can_receive_mentor_training

      graph.add_conditional_edge(
        from: :can_receive_mentor_training,
        when: ->(step) { step.lp_will_provide == 'no' },
        then: :which_lead_provider,
        else: :confirmation,
        label: 'LP provides?',
      )

      graph.add_edge from: :which_lead_provider, to: :confirmation
    end
  end

  def route_strategy
    DfE::Wizard::RouteStrategy::NamedRoutes.new(
      wizard: self,
      namespace: 'assign_mentor',
    )
  end
end
