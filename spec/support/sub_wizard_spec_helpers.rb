module SubWizardSpecSteps
  class Start
    include DfE::Wizard::Step
  end

  class Funding
    include DfE::Wizard::Step

    attribute :funding, :string
  end

  class Student
    include DfE::Wizard::Step

    attribute :student_visa, :boolean
  end

  class Skilled
    include DfE::Wizard::Step

    attribute :skilled_visa, :boolean
  end

  class DeadlineRequired
    include DfE::Wizard::Step

    attribute :deadline_required, :boolean
  end

  class DeadlineAt
    include DfE::Wizard::Step

    attribute :deadline_at, :string
  end

  class StartDate
    include DfE::Wizard::Step
  end

  class Review
    include DfE::Wizard::Step
  end
end

class SubWizardSpecStore
  include DfE::Wizard::StateStore

  def salaried?
    read[:funding] == 'salary'
  end

  def student_visa?
    read[:student_visa] == true
  end

  def skilled_visa?
    read[:skilled_visa] == true
  end

  def deadline_required?
    read[:deadline_required] == true
  end
end

module SubWizardSpecHelpers
  VISA_STEPS = %i[student skilled deadline_required deadline_at].freeze

  # VISA_STEPS for example groups, where the constant does not resolve.
  def visa_steps
    VISA_STEPS
  end

  def build_wizard(store: SubWizardSpecStore.new, &draw)
    wizard_class = Class.new do
      include DfE::Wizard

      define_method(:steps_processor) do
        DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) { |graph| draw.call(graph) }
      end

      def logger
        nil
      end

      def route_strategy
        nil
      end
    end

    wizard_class.new(state_store: store)
  end

  def parent_nodes(graph)
    graph.add_node :start, SubWizardSpecSteps::Start
    graph.add_node :funding, SubWizardSpecSteps::Funding
    graph.add_node :start_date, SubWizardSpecSteps::StartDate
    graph.add_node :review, SubWizardSpecSteps::Review
    graph.root :start
  end

  # Parent edges. They name the unit's real first steps (no entry).
  def parent_edges(graph)
    graph.add_edge from: :start, to: :funding
    graph.add_multiple_conditional_edges(
      from: :funding,
      branches: [{ when: :salaried?, then: :skilled }],
      default: :student,
    )
    graph.add_edge from: :start_date, to: :review
  end

  def visa_nodes(graph)
    graph.add_node :student, SubWizardSpecSteps::Student
    graph.add_node :skilled, SubWizardSpecSteps::Skilled
    graph.add_node :deadline_required, SubWizardSpecSteps::DeadlineRequired
    graph.add_node :deadline_at, SubWizardSpecSteps::DeadlineAt
  end

  # The visa edges in the parent graph. With exits: false, the exits to
  # start_date are left open for exit_to.
  def visa_edges(graph, exits: true)
    default = exits ? :start_date : nil
    graph.add_multiple_conditional_edges(
      from: :student, branches: [{ when: :student_visa?, then: :deadline_required }], default:,
    )
    graph.add_multiple_conditional_edges(
      from: :skilled, branches: [{ when: :skilled_visa?, then: :deadline_required }], default:,
    )
    graph.add_multiple_conditional_edges(
      from: :deadline_required, branches: [{ when: :deadline_required?, then: :deadline_at }], default:,
    )
    graph.add_edge from: :deadline_at, to: :start_date if exits
  end

  # Answer sets that cover every branch of the visa graph.
  def visa_answer_sets
    [
      {},
      { funding: 'fee', student_visa: false },
      { funding: 'fee', student_visa: true, deadline_required: false },
      { funding: 'fee', student_visa: true, deadline_required: true },
      { funding: 'salary', skilled_visa: false },
      { funding: 'salary', skilled_visa: true, deadline_required: true },
    ]
  end
end
