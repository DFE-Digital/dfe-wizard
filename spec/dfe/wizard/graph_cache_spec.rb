RSpec.describe DfE::Wizard, 'graph cache' do
  module GraphCacheSteps
    class Name
      include DfE::Wizard::Step

      attribute :name, :string

      validates :name, presence: true

      def self.permitted_params
        %i[name]
      end
    end

    class Nationality
      include DfE::Wizard::Step

      attribute :nationality, :string

      validates :nationality, presence: true

      def self.permitted_params
        %i[nationality]
      end
    end

    class Visa
      include DfE::Wizard::Step

      # :name is also declared by Name, so unflatten_state must keep it on :name
      attribute :name, :string
      attribute :visa_type, :string

      def self.permitted_params
        %i[visa_type]
      end
    end

    class Review
      include DfE::Wizard::Step

      def self.permitted_params
        []
      end
    end
  end

  class GraphCacheStateStore
    include DfE::Wizard::StateStore

    def needs_visa?
      read[:nationality] == 'other'
    end

    def returning?
      read[:returning] == true
    end
  end

  class GraphCacheWizard
    include DfE::Wizard

    def steps_processor
      DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
        graph.add_node :name, GraphCacheSteps::Name
        graph.add_node :nationality, GraphCacheSteps::Nationality
        graph.add_node :visa, GraphCacheSteps::Visa
        graph.add_node :review, GraphCacheSteps::Review

        graph.conditional_root(potential_root: %i[name nationality]) do |store|
          store.returning? ? :nationality : :name
        end

        graph.add_edge from: :name, to: :nationality
        graph.add_conditional_edge(
          from: :nationality,
          when: :needs_visa?,
          then: :visa,
          else: :review,
        )
        graph.add_edge from: :visa, to: :review
      end
    end

    def logger
      nil
    end

    def route_strategy
      nil
    end
  end

  def build_wizard(current_step: :name, current_step_params: {}, state_store: GraphCacheStateStore.new)
    GraphCacheWizard.new(state_store:, current_step:, current_step_params:)
  end

  describe 'draw count' do
    before do
      allow(DfE::Wizard::StepsProcessor::Graph).to receive(:draw).and_call_original
    end

    it 'draws the graph once per wizard instance' do
      wizard = build_wizard(current_step: :nationality)
      wizard.state_store.write(name: 'Ann', nationality: 'other', visa_type: 'skilled')

      wizard.next_step
      wizard.previous_step
      wizard.flow_path(:review)
      wizard.valid_path_to?(:review)
      wizard.find_step(:visa)
      wizard.step_definitions
      wizard.raw_data
      wizard.full_path

      expect(DfE::Wizard::StepsProcessor::Graph).to have_received(:draw).once
    end

    it 'draws once for each wizard instance, and each follows its own state store' do
      british = build_wizard(current_step: :nationality)
      other = build_wizard(current_step: :nationality)
      british.state_store.write(nationality: 'british')
      other.state_store.write(nationality: 'other')

      expect(british.next_step).to eq(:review)
      expect(other.next_step).to eq(:visa)
      expect(DfE::Wizard::StepsProcessor::Graph).to have_received(:draw).twice
    end
  end

  describe 'answers written after the draw' do
    it 'takes the branch for an answer written in the same request' do
      wizard = build_wizard(current_step: :nationality)

      wizard.state_store.write(nationality: 'british')
      expect(wizard.next_step).to eq(:review)

      wizard.state_store.write(nationality: 'other')
      expect(wizard.next_step).to eq(:visa)
    end

    it 'takes the branch for an answer saved by save_current_step' do
      wizard = build_wizard(
        current_step: :nationality,
        current_step_params: { nationality: { nationality: 'other' } },
      )

      expect(wizard.save_current_step).to be(true)
      expect(wizard.next_step).to eq(:visa)
    end

    it 're-evaluates a conditional root' do
      wizard = build_wizard

      expect(wizard.root_step).to eq(:name)

      wizard.state_store.write(returning: true)
      expect(wizard.root_step).to eq(:nationality)
    end
  end

  describe 'setters' do
    it 'respects current_step_name=' do
      wizard = build_wizard
      wizard.state_store.write(nationality: 'other')

      expect(wizard.next_step).to eq(:nationality)

      wizard.current_step_name = :nationality
      expect(wizard.next_step).to eq(:visa)
    end

    it 'respects current_step_params=' do
      wizard = build_wizard(current_step: :nationality)
      wizard.current_step_params = { nationality: { nationality: 'other' } }

      expect(wizard.save_current_step).to be(true)
      expect(wizard.next_step).to eq(:visa)
    end

    it 'clears the cache in state_store= and uses the new store' do
      allow(DfE::Wizard::StepsProcessor::Graph).to receive(:draw).and_call_original
      wizard = build_wizard(current_step: :nationality)
      wizard.state_store.write(nationality: 'british')
      expect(wizard.next_step).to eq(:review)

      new_store = GraphCacheStateStore.new
      new_store.write(nationality: 'other')
      wizard.state_store = new_store

      expect(wizard.state_store).to be(new_store)
      expect(wizard.next_step).to eq(:visa)
      expect(DfE::Wizard::StepsProcessor::Graph).to have_received(:draw).twice
    end
  end

  describe 'unflatten_state' do
    it 'gives each attribute to its first declaring step, as in 1.0' do
      wizard = build_wizard
      wizard.state_store.write(name: 'Ann', visa_type: 'skilled', returning: true)

      expect(wizard.raw_data).to eq(
        steps: {
          name: { name: 'Ann' },
          visa: { visa_type: 'skilled' },
        },
        returning: true,
      )
    end

    it 'reads the step definitions at most once' do
      wizard = build_wizard
      wizard.state_store.write(name: 'Ann', nationality: 'other', visa_type: 'skilled')
      processor = wizard.send(:cached_steps_processor)
      allow(processor).to receive(:step_definitions).and_call_original

      wizard.raw_data

      expect(processor).to have_received(:step_definitions).at_most(:once)
    end
  end

  describe 'stubbing a Symbol predicate after the wizard is built' do
    # Documented limitation: the graph binds Symbol predicates to the state
    # store when it is drawn, so a stub added later is not seen. Stub before
    # building the wizard, or use a lambda predicate.
    it 'is not seen by the cached graph' do
      wizard = build_wizard(current_step: :nationality)
      wizard.state_store.write(nationality: 'british')
      allow(wizard.state_store).to receive(:needs_visa?).and_return(true)

      expect(wizard.next_step).to eq(:review)
    end
  end
end
