# A wizard with a check answers node, for change journey specs. Its graph
# is the sub-wizard spec graph: funding chooses the student or skilled
# visa step, the visa sub-wizard (class form) exits to start_date, and
# start_date goes to check answers. Visa depends on funding.
class JourneySpecRoutes
  def resolve(step_id:, options: {})
    query = options.empty? ? '' : "?#{options.to_query}"
    "/journey/#{step_id}#{query}"
  end
end

class JourneySpecWizard
  include DfE::Wizard

  def steps_processor
    DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
      graph.add_node :start, SubWizardSpecSteps::Start
      graph.add_node :funding, SubWizardSpecSteps::Funding
      graph.add_sub_wizard :visa, SubWizardSpecVisa, exit_to: :start_date, depends_on: %i[funding]
      graph.add_node :start_date, SubWizardSpecSteps::StartDate, depends_on: start_date_depends_on
      graph.add_node :check_answers, SubWizardSpecSteps::Review
      graph.root :start
      graph.check_answers :check_answers

      graph.add_edge from: :start, to: :funding
      graph.add_multiple_conditional_edges(
        from: :funding,
        branches: [{ when: :salaried?, then: :skilled }],
        default: :student,
      )
      graph.add_edge from: :start_date, to: :check_answers
    end
  end

  # Overridden by specs that need a second dependent unit
  def start_date_depends_on
    []
  end

  def logger
    nil
  end

  def route_strategy
    JourneySpecRoutes.new
  end
end

# start_date also depends on funding, so a funding change queues two units.
class JourneySpecTwoUnitWizard < JourneySpecWizard
  def start_date_depends_on
    %i[funding]
  end
end

module JourneySpecHelpers
  # A fee-funded draft with no student visa, ready for check answers.
  COMPLETE_FEE_DRAFT = { funding: 'fee', student_visa: false }.freeze

  def journey_repository
    @journey_repository ||= DfE::Wizard::Repository::InMemory.new
  end

  def journey_store
    SubWizardSpecStore.new(repository: journey_repository)
  end

  # One request: a wizard built for a step, as a controller builds it.
  def journey_request(step, params = {}, wizard_class: journey_wizard_class)
    wizard_class.new(state_store: journey_store, current_step: step, current_step_params: params)
  end

  # The wizard every helper builds; override with let(:journey_wizard_class)
  def journey_wizard_class
    JourneySpecWizard
  end

  # GET a step. Returns the journey start redirect, or nil.
  def visit_step(step, params = {})
    journey_request(step, params).journey_start_redirect
  end

  # PATCH a step with answers. Returns the next step id.
  def submit_step(step, answers = {})
    wizard = journey_request(step, { step => answers })
    raise "save failed on #{step}" unless wizard.save_current_step

    wizard.next_step
  end

  def back_from(step)
    journey_request(step).previous_step
  end

  def journey_state
    journey_request(:start).changeset.journey
  end
end
