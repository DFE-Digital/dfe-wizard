RSpec.describe 'Change journeys' do
  include JourneySpecHelpers

  before do
    journey_store.write(**JourneySpecHelpers::COMPLETE_FEE_DRAFT)
  end

  describe 'starting' do
    it 'redirects to the first step of the unit, without the start param' do
      expect(visit_step(:funding, return_to_review: :funding)).to eq('/journey/funding')
    end

    it 'opens on the named step when it is on the path' do
      journey_store.write(funding: 'salary', skilled_visa: true, deadline_required: false, student_visa: nil)

      expect(visit_step(:deadline_required, return_to_review: :deadline_required)).to eq('/journey/deadline_required')
      expect(journey_state).to include(unit: 'visa', entry: 'deadline_required')
    end

    it 'starts at the first step of a sub-wizard on the path when the named step is not on it' do
      expect(visit_step(:deadline_at, 'return_to_review' => 'deadline_at')).to eq('/journey/student')
    end

    it 'stores the unit, an empty shown list, the snapshot and the entry step' do
      visit_step(:funding, return_to_review: :funding)

      expect(journey_state).to eq(
        unit: 'funding', shown: [], snapshot: { funding: 'fee', student_visa: false }, entry: 'funding',
      )
    end

    it 'restarts on every start param, replacing the old journey' do
      visit_step(:funding, return_to_review: :funding)
      submit_step(:funding, funding: 'salary')
      visit_step(:start_date, return_to_review: :start_date)

      expect(journey_state).to eq(
        unit: 'start_date', shown: [], snapshot: { funding: 'salary', student_visa: false }, entry: 'start_date',
      )
    end

    it 'does nothing without the start param' do
      expect(visit_step(:funding)).to be_nil
      expect(journey_state).to be_nil
    end

    it 'does nothing for an id that is not a step' do
      expect(visit_step(:funding, return_to_review: :nope)).to be_nil
    end

    it 'does nothing for the check answers node' do
      expect(visit_step(:check_answers, return_to_review: :check_answers)).to be_nil
    end

    it 'goes back to check answers when the unit has no step on the path' do
      wizard = journey_request(:orphan, { return_to_review: :orphan }, wizard_class: orphan_wizard_class)

      expect(wizard.journey_start_redirect).to eq('/journey/check_answers')
      expect(wizard.changeset.journey).to be_nil
    end

    it 'returns nil for a wizard that does not declare check_answers' do
      wizard = build_plain_wizard(current_step_params: { return_to_review: :funding })

      expect(wizard.journey_start_redirect).to be_nil
    end
  end

  describe 'a unit with no change' do
    it 'returns to check answers' do
      visit_step(:funding, return_to_review: :funding)

      expect(submit_step(:funding, funding: 'fee')).to eq(:check_answers)
      expect(journey_state).to be_nil
    end
  end

  describe 'a sub-wizard' do
    it 'shows each step of the unit on the path, then returns (the visa bug)' do
      journey_store.write(funding: 'salary', skilled_visa: false, student_visa: nil)
      expect(visit_step(:skilled, return_to_review: :skilled)).to eq('/journey/skilled')

      expect(submit_step(:skilled, skilled_visa: true)).to eq(:deadline_required)
      expect(submit_step(:deadline_required, deadline_required: false)).to eq(:check_answers)
    end
  end

  describe 'an entry step inside a sub-wizard' do
    before do
      journey_store.write(funding: 'salary', skilled_visa: true, deadline_required: true, student_visa: nil)
      visit_step(:deadline_required, return_to_review: :deadline_required)
    end

    it 'goes Back from the entry step to check answers' do
      expect(back_from(:deadline_required)).to eq(:check_answers)
    end

    it 'shows the steps of the unit after the entry step, then returns' do
      expect(submit_step(:deadline_required, deadline_required: true)).to eq(:deadline_at)
      expect(back_from(:deadline_at)).to eq(:deadline_required)
      expect(submit_step(:deadline_at, deadline_at: '2027-01-01')).to eq(:check_answers)
    end

    it 'treats a step of the unit before the entry step as outside the journey' do
      expect(back_from(:skilled)).to eq(:funding)
      expect(submit_step(:skilled, skilled_visa: true)).to eq(:deadline_required)
      expect(journey_state).to include(unit: 'visa', entry: 'deadline_required')
    end
  end

  describe 'Back inside one unit' do
    before do
      journey_store.write(funding: 'salary', skilled_visa: false, student_visa: nil)
      visit_step(:skilled, return_to_review: :skilled)
      submit_step(:skilled, skilled_visa: true)
    end

    it 'goes to the previous step of the unit on the path' do
      expect(back_from(:deadline_required)).to eq(:skilled)
    end

    it 'goes from the first step of the only unit to check answers' do
      expect(back_from(:skilled)).to eq(:check_answers)
    end

    it 'uses 1.0 navigation for a step outside the journey' do
      expect(back_from(:funding)).to eq(:start)
    end
  end

  describe 'a save outside the journey' do
    it 'uses 1.0 navigation and leaves the journey as it is' do
      visit_step(:funding, return_to_review: :funding)
      state = journey_state

      expect(submit_step(:start)).to eq(:funding)
      expect(journey_state).to eq(state)
    end

    it 'uses 1.0 navigation on check answers' do
      visit_step(:funding, return_to_review: :funding)

      expect(journey_request(:check_answers).next_step).to be_nil
    end
  end

  describe 'precedence over app callbacks' do
    let(:wizard_class) do
      Class.new(JourneySpecWizard) do
        def steps_processor
          super.tap do |graph|
            graph.registry.add_before_next_callback(-> { :start })
          end
        end
      end
    end

    it 'runs the journey callback first during a journey' do
      journey_store.write(funding: 'salary', skilled_visa: false)
      visit_step(:skilled, return_to_review: :skilled)
      wizard = journey_request(:skilled, { skilled: { skilled_visa: true } }, wizard_class:)
      wizard.save_current_step

      expect(wizard.next_step).to eq(:deadline_required)
    end

    it 'lets the app callback run outside a journey' do
      expect(journey_request(:funding, {}, wizard_class:).next_step).to eq(:start)
    end
  end

  def orphan_wizard_class
    Class.new(JourneySpecWizard) do
      def steps_processor
        DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
          graph.add_node :start, SubWizardSpecSteps::Start
          graph.add_node :orphan, SubWizardSpecSteps::Funding
          graph.add_node :check_answers, SubWizardSpecSteps::Review
          graph.root :start
          graph.check_answers :check_answers
          graph.add_edge from: :start, to: :check_answers
        end
      end
    end
  end

  def build_plain_wizard(current_step_params:)
    Class.new(JourneySpecWizard) do
      def steps_processor
        DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
          graph.add_node :funding, SubWizardSpecSteps::Funding
          graph.root :funding
        end
      end
    end.new(state_store: journey_store, current_step: :funding, current_step_params:)
  end
end
