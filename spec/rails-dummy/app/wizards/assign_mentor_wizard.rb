class AssignMentorWizard < DfE::Wizard::Base
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
        when: lambda { |data|
          data.dig(:steps, :can_receive_mentor_training, :lp_will_provide) == 'no'
        },
        then: :which_lead_provider,
        else: :confirmation,
        label: 'LP provides?',
      )

      graph.add_edge from: :which_lead_provider, to: :confirmation
    end
  end

  def route_strategy
    DfE::Wizard::RouteStrategy::NamedRoutes.new(
      namespace: 'assign_mentor',
    )
  end

  def current_step_accessible?
    traversal = steps_processor.path_traversal(current_step_name, data)

    steps = traversal[0..-2].map do |step_id|
      klass = find_step(step_id)
      step_data = data.dig(:steps, step_id) || {}

      klass.new(step_data.merge(wizard: self, step_id:))
    end

    steps_processor.root_node == current_step_name || (steps.present? && steps.all?(&:valid?))
  end
end
