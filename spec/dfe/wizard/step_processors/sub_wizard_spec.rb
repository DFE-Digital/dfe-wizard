RSpec.describe DfE::Wizard::StepsProcessor::Graph, 'sub-wizards' do
  include SubWizardSpecHelpers

  def explicit_visa_wizard(store: SubWizardSpecStore.new, exits: true, exit_to: nil)
    build_wizard(store:) do |g|
      parent_nodes(g)
      visa_nodes(g)
      visa_edges(g, exits:)
      g.add_sub_wizard :visa, steps: visa_steps, exit_to: exit_to
      parent_edges(g)
    end
  end

  def plain_visa_wizard(store: SubWizardSpecStore.new)
    build_wizard(store:) do |g|
      parent_nodes(g)
      visa_nodes(g)
      visa_edges(g)
      parent_edges(g)
    end
  end

  describe 'the explicit form' do
    it 'records the sub-wizard as a unit' do
      unit = explicit_visa_wizard.steps_processor.sub_wizards.fetch(:visa)

      expect(unit).to have_attributes(id: :visa, step_ids: visa_steps, exit_to: nil, uses: [], source: nil)
    end

    it 'changes no path, step or transition' do
      visa_answer_sets.each do |answers|
        with_unit = explicit_visa_wizard(store: SubWizardSpecStore.new.tap { |s| s.write(answers) })
        without = plain_visa_wizard(store: SubWizardSpecStore.new.tap { |s| s.write(answers) })

        expect(with_unit.steps_processor.full_path).to eq(without.steps_processor.full_path), answers.inspect
      end

      with_unit = explicit_visa_wizard.steps_processor
      without = plain_visa_wizard.steps_processor
      expect(with_unit.step_definitions).to eq(without.step_definitions)
      expect(with_unit.metadata).to eq(without.metadata)
    end

    it 'follows the visa branches' do
      store = SubWizardSpecStore.new
      store.write(funding: 'salary', skilled_visa: true, deadline_required: true)

      expect(explicit_visa_wizard(store:).steps_processor.full_path)
        .to eq(%i[start funding skilled deadline_required deadline_at start_date review])
    end
  end

  describe '#unit_for' do
    let(:graph) { explicit_visa_wizard.steps_processor }

    it 'returns the sub-wizard for one of its steps' do
      expect(graph.unit_for(:deadline_at)).to be(graph.sub_wizards[:visa])
    end

    it 'returns a single-step unit for a step outside every sub-wizard' do
      expect(graph.unit_for(:funding)).to have_attributes(id: :funding, step_ids: [:funding], exit_to: nil, uses: [])
    end

    it 'returns nil for an id that is not a node' do
      expect(graph.unit_for(:nope)).to be_nil
    end
  end

  describe 'exit_to:' do
    it 'sends every open exit to the exit_to node' do
      visa_answer_sets.each do |answers|
        wired = explicit_visa_wizard(exits: false, exit_to: :start_date,
                                     store: SubWizardSpecStore.new.tap { |s| s.write(answers) })
        by_hand = plain_visa_wizard(store: SubWizardSpecStore.new.tap { |s| s.write(answers) })

        expect(wired.steps_processor.full_path).to eq(by_hand.steps_processor.full_path), answers.inspect
      end
    end

    it 'adds a simple edge from a step with no edge' do
      wizard = build_wizard do |g|
        g.add_node :a, SubWizardSpecSteps::Start
        g.add_node :b, SubWizardSpecSteps::Review
        g.root :a
        g.add_sub_wizard :unit, steps: [:a], exit_to: :b
      end

      expect(wizard.steps_processor.next_step(:a)).to eq(:b)
    end

    it 'is the fallback for a conditional edge with a nil branch' do
      wizard = build_wizard do |g|
        g.add_node :a, SubWizardSpecSteps::Funding
        g.add_node :b, SubWizardSpecSteps::Review
        g.add_node :c, SubWizardSpecSteps::StartDate
        g.root :a
        g.add_conditional_edge from: :a, when: :salaried?, then: :c, else: nil
        g.add_sub_wizard :unit, steps: %i[a c], exit_to: :b
      end

      expect(wizard.steps_processor.next_step(:a)).to eq(:b)
    end

    it 'is the fallback for a custom edge that returns nil' do
      wizard = build_wizard do |g|
        g.add_node :a, SubWizardSpecSteps::Funding
        g.add_node :b, SubWizardSpecSteps::Review
        g.root :a
        g.add_custom_branching_edge(from: :a, conditional: -> {}, potential_transitions: [])
        g.add_sub_wizard :unit, steps: [:a], exit_to: :b
      end

      expect(wizard.steps_processor.next_step(:a)).to eq(:b)
    end

    it "keeps a step's own simple edge" do
      wizard = build_wizard do |g|
        g.add_node :a, SubWizardSpecSteps::Start
        g.add_node :b, SubWizardSpecSteps::Funding
        g.add_node :c, SubWizardSpecSteps::Review
        g.root :a
        g.add_edge from: :a, to: :b
        g.add_sub_wizard :unit, steps: %i[a b], exit_to: :c
      end
      graph = wizard.steps_processor

      expect(graph.next_step(:a)).to eq(:b)
      expect(graph.next_step(:b)).to eq(:c)
      expect(graph.registry.edges.count { |edge| edge.from == :a }).to eq(1)
    end

    it 'records exit_to on the unit' do
      graph = explicit_visa_wizard(exits: false, exit_to: :start_date).steps_processor

      expect(graph.sub_wizards[:visa].exit_to).to eq(:start_date)
    end

    it 'raises when exit_to is one of the unit steps' do
      expect { explicit_visa_wizard(exits: false, exit_to: :student).steps_processor }
        .to raise_error(DfE::Wizard::InvalidGraph, 'sub-wizard :visa: exit_to :student is one of its own steps')
    end
  end

  describe 'declaration errors' do
    def declare(*args, **kwargs)
      build_wizard do |g|
        parent_nodes(g)
        visa_nodes(g)
        g.add_sub_wizard(*args, **kwargs)
      end.steps_processor
    end

    it 'raises for an id that is not a Symbol' do
      expect { declare('visa', steps: visa_steps) }
        .to raise_error(DfE::Wizard::InvalidGraph, 'sub-wizard id must be a Symbol, got String')
    end

    it 'raises for an id declared twice' do
      expect do
        build_wizard do |g|
          parent_nodes(g)
          visa_nodes(g)
          g.add_sub_wizard :visa, steps: %i[student]
          g.add_sub_wizard :visa, steps: %i[skilled]
        end.steps_processor
      end.to raise_error(DfE::Wizard::InvalidGraph, 'sub-wizard :visa is declared twice')
    end

    it 'raises for empty steps' do
      expect { declare(:visa, steps: []) }
        .to raise_error(DfE::Wizard::InvalidGraph, 'sub-wizard :visa: steps: must be a non-empty Array of Symbols')
    end

    it 'raises for a step id that is not a Symbol' do
      expect { declare(:visa, steps: ['student']) }
        .to raise_error(DfE::Wizard::InvalidGraph, 'sub-wizard :visa: steps: must be a non-empty Array of Symbols')
    end

    it 'raises for an exit_to that is not a Symbol' do
      expect { declare(:visa, steps: visa_steps, exit_to: 'start_date') }
        .to raise_error(DfE::Wizard::InvalidGraph, 'sub-wizard :visa: exit_to must be a Symbol, got String')
    end

    it 'is an ArgumentError, as other draw errors are' do
      expect { declare(:visa, steps: []) }.to raise_error(ArgumentError)
    end
  end
end
