RSpec.describe 'change journeys tooling' do
  include SubWizardSpecHelpers
  include JourneySpecHelpers

  def draw(&block)
    build_wizard(store: SubWizardSpecStore.new(repository: DfE::Wizard::Repository::InMemory.new), &block)
  end

  describe 'graph.change_journeys' do
    it 'lists each depends_on answer with the units that name it' do
      graph = journey_request(:start, wizard_class: JourneySpecTwoUnitWizard).steps_processor

      expect(graph.change_journeys).to eq(funding: %i[visa start_date])
    end

    it 'orders the units by their first declared step, not by the path' do
      wizard = draw do |g|
        g.add_node :start, SubWizardSpecSteps::Start
        g.add_node :funding, SubWizardSpecSteps::Funding
        g.add_node :start_date, SubWizardSpecSteps::StartDate, depends_on: %i[funding]
        g.add_node :review, SubWizardSpecSteps::Review
        g.root :start
        g.add_sub_wizard :visa, SubWizardSpecVisa, exit_to: :start_date, depends_on: %i[funding]
      end

      expect(wizard.steps_processor.change_journeys).to eq(funding: %i[start_date visa])
    end

    it 'leaves out a unit that depends on its own answer' do
      wizard = draw do |g|
        parent_nodes(g)
        g.add_sub_wizard :visa, SubWizardSpecVisa, exit_to: :start_date, depends_on: %i[funding student_visa]
      end

      expect(wizard.steps_processor.change_journeys).to eq(funding: %i[visa])
    end

    it 'is empty when no unit declares depends_on' do
      wizard = draw { |g| parent_nodes(g) }

      expect(wizard.steps_processor.change_journeys).to eq({})
    end

    it 'is empty for a Linear processor' do
      processor = DfE::Wizard::StepsProcessor::Linear.draw(nil) do |linear|
        linear.add_step :start, SubWizardSpecSteps::Start
      end

      expect(processor.change_journeys).to eq({})
    end
  end

  describe 'wizard.change_journey' do
    let(:wizard) { journey_request(:start, wizard_class: JourneySpecTwoUnitWizard) }

    it 'returns the units that a change to the answer queues' do
      expect(wizard.change_journey(:funding)).to eq(%i[visa start_date])
    end

    it 'accepts a String' do
      expect(wizard.change_journey('funding')).to eq(%i[visa start_date])
    end

    it 'returns no units for an answer that no unit depends on' do
      expect(wizard.change_journey(:student_visa)).to eq([])
    end

    it 'raises for a name that is not a step attribute' do
      expect { wizard.change_journey(:fundng) }
        .to raise_error(ArgumentError, ':fundng is not a step attribute')
    end

    it 'does not need graph.check_answers' do
      plain = draw do |g|
        parent_nodes(g)
        g.add_sub_wizard :visa, SubWizardSpecVisa, exit_to: :start_date, depends_on: %i[funding]
      end

      expect(plain.change_journey(:funding)).to eq(%i[visa])
    end
  end

  describe 'metadata' do
    let(:metadata) { journey_request(:start, wizard_class: JourneySpecTwoUnitWizard).metadata.to_h }

    it 'describes each sub-wizard' do
      expect(metadata[:sub_wizards]).to eq(
        visa: {
          steps: %i[student skilled deadline_required deadline_at],
          exit_to: :start_date,
          depends_on: %i[funding],
        },
      )
    end

    it 'describes each change journey with the step that owns the answer' do
      expect(metadata[:change_journeys]).to eq(funding: { from: :funding, units: %i[visa start_date] })
    end

    it 'names the step that owns the answer when its class has no name' do
      wizard = draw do |g|
        g.add_node :start, SubWizardSpecSteps::Start
        g.add_node :funding, Class.new(SubWizardSpecSteps::Funding)
        g.add_node :start_date, SubWizardSpecSteps::StartDate, depends_on: %i[funding]
        g.root :start
      end

      expect(wizard.metadata.to_h[:change_journeys]).to eq(funding: { from: :funding, units: %i[start_date] })
    end

    it 'draws the graph once' do
      wizard = journey_request(:start, wizard_class: JourneySpecTwoUnitWizard)
      allow(wizard).to receive(:steps_processor).and_call_original

      wizard.metadata

      expect(wizard).to have_received(:steps_processor).once
    end

    it 'leaves both keys out for a graph that declares neither' do
      metadata = draw { |g| parent_nodes(g) }.metadata.to_h

      expect(metadata).not_to include(:sub_wizards, :change_journeys)
    end
  end
end
