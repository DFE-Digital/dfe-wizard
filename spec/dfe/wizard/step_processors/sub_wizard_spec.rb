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

  def class_visa_wizard(store: SubWizardSpecStore.new, sub_wizard: SubWizardSpecVisa)
    build_wizard(store:) do |g|
      parent_nodes(g)
      g.add_sub_wizard :visa, sub_wizard, exit_to: :start_date
      parent_edges(g)
    end
  end

  # For a test class that does not draw the visa steps: the parent edges
  # name :skilled and :student, so they are left out.
  def custom_wizard(sub_wizard)
    build_wizard do |g|
      parent_nodes(g)
      g.add_sub_wizard :visa, sub_wizard, exit_to: :start_date
    end
  end

  describe 'the class form' do
    it 'records the nodes the class drew, in draw order' do
      unit = class_visa_wizard.steps_processor.sub_wizards.fetch(:visa)

      expect(unit).to have_attributes(
        id: :visa,
        step_ids: visa_steps,
        exit_to: :start_date,
        uses: %i[student_visa? skilled_visa? deadline_required?],
        source: SubWizardSpecVisa,
      )
    end

    it 'gives the same paths as the explicit form' do
      visa_answer_sets.each do |answers|
        class_form = class_visa_wizard(store: SubWizardSpecStore.new.tap { |s| s.write(answers) })
        explicit = plain_visa_wizard(store: SubWizardSpecStore.new.tap { |s| s.write(answers) })

        expect(class_form.steps_processor.full_path).to eq(explicit.steps_processor.full_path), answers.inspect
      end
    end

    it 'gives the same step definitions as the explicit form' do
      expect(class_visa_wizard.steps_processor.step_definitions)
        .to eq(plain_visa_wizard.steps_processor.step_definitions)
    end

    it 'accepts a lambda that draws' do
      drawer = lambda do |graph|
        graph.add_node :student, SubWizardSpecSteps::Student
      end
      wizard = build_wizard do |g|
        parent_nodes(g)
        g.add_sub_wizard :visa, drawer, exit_to: :start_date
        g.add_edge from: :funding, to: :student
        g.add_edge from: :start, to: :funding
      end

      expect(wizard.steps_processor.sub_wizards[:visa]).to have_attributes(step_ids: [:student], uses: [])
      expect(wizard.steps_processor.next_step(:student)).to eq(:start_date)
    end

    it 'raises for an object that cannot draw' do
      expect { custom_wizard(Object.new).steps_processor }
        .to raise_error(DfE::Wizard::InvalidGraph, 'sub-wizard :visa must respond to draw(graph) or call(graph)')
    end

    it 'raises when the class draws no nodes' do
      empty = Class.new do
        def self.draw(_graph)
          nil
        end
      end

      expect { custom_wizard(empty).steps_processor }
        .to raise_error(DfE::Wizard::InvalidGraph, 'sub-wizard :visa drew no nodes')
    end

    it 'raises when given both steps: and a class' do
      expect do
        build_wizard do |g|
          parent_nodes(g)
          g.add_sub_wizard :visa, SubWizardSpecVisa, steps: visa_steps
        end.steps_processor
      end.to raise_error(DfE::Wizard::InvalidGraph, 'sub-wizard :visa takes steps: or a sub-wizard object, not both')
    end

    it 'raises when given neither' do
      expect do
        build_wizard do |g|
          parent_nodes(g)
          g.add_sub_wizard :visa
        end.steps_processor
      end.to raise_error(DfE::Wizard::InvalidGraph,
                         'sub-wizard :visa needs steps: or an object that responds to draw(graph)')
    end
  end

  describe 'uses' do
    it 'collects names across calls, once each' do
      sub_wizard = Class.new do
        extend DfE::Wizard::SubWizard

        uses :student_visa?
        uses :skilled_visa?, :student_visa?
      end

      expect(sub_wizard.uses).to eq(%i[student_visa? skilled_visa?])
    end

    it 'raises when the state store does not define a used method' do
      sub_wizard = Class.new do
        extend DfE::Wizard::SubWizard

        uses(*SubWizardSpecVisa.uses, :provider)

        def self.name
          'MissingVisa'
        end

        def self.draw(graph)
          SubWizardSpecVisa.draw(graph)
        end
      end

      expect { custom_wizard(sub_wizard).steps_processor }
        .to raise_error(DfE::Wizard::InvalidGraph,
                        'sub-wizard :visa (MissingVisa) uses :provider, which SubWizardSpecStore does not define')
    end
  end

  describe 'rule 7: predicates are Symbols listed in uses' do
    def drawing(&body)
      Class.new do
        extend DfE::Wizard::SubWizard

        uses :student_visa?

        define_singleton_method(:name) { 'TestVisa' }
        define_singleton_method(:draw) do |graph|
          graph.add_node :student, SubWizardSpecSteps::Student
          graph.add_node :deadline_required, SubWizardSpecSteps::DeadlineRequired
          body.call(graph)
        end
      end
    end

    it 'accepts a listed Symbol' do
      sub_wizard = drawing do |g|
        g.add_conditional_edge from: :student, when: :student_visa?, then: :deadline_required, else: nil
      end

      expect { custom_wizard(sub_wizard).steps_processor }.not_to raise_error
    end

    it 'raises for a lambda on an edge' do
      sub_wizard = drawing do |g|
        g.add_conditional_edge from: :student, when: -> { true }, then: :deadline_required, else: nil
      end

      expect { custom_wizard(sub_wizard).steps_processor }
        .to raise_error(DfE::Wizard::InvalidGraph,
                        'sub-wizard :visa (TestVisa): the edge from :student uses a Proc; ' \
                        'a sub-wizard predicate must be a Symbol listed in uses')
    end

    it 'raises for a Symbol not listed in uses' do
      sub_wizard = drawing do |g|
        g.add_multiple_conditional_edges(from: :student, branches: [{ when: :salaried?, then: :deadline_required }])
      end

      expect { custom_wizard(sub_wizard).steps_processor }
        .to raise_error(DfE::Wizard::InvalidGraph,
                        'sub-wizard :visa (TestVisa): a branch from :student uses :salaried?, ' \
                        'which is not listed in uses')
    end

    it 'raises for a lambda skip_when' do
      sub_wizard = drawing do |g|
        g.add_node :deadline_at, SubWizardSpecSteps::DeadlineAt, skip_when: -> { true }
      end

      expect { custom_wizard(sub_wizard).steps_processor }
        .to raise_error(DfE::Wizard::InvalidGraph, /skip_when on :deadline_at uses a Proc/)
    end

    it 'raises for a proc on a custom edge' do
      sub_wizard = drawing do |g|
        g.add_custom_branching_edge(from: :student, conditional: proc { :deadline_required }, potential_transitions: [])
      end

      expect { custom_wizard(sub_wizard).steps_processor }
        .to raise_error(DfE::Wizard::InvalidGraph, /the custom edge from :student uses a Proc/)
    end

    it 'allows a class with no uses to add nodes and simple edges only' do
      drawer = lambda do |graph|
        graph.add_node :student, SubWizardSpecSteps::Student
        graph.add_node :deadline_required, SubWizardSpecSteps::DeadlineRequired
        graph.add_edge from: :student, to: :deadline_required
        graph.add_conditional_edge from: :student, when: :student_visa?, then: :deadline_required, else: nil
      end

      expect { custom_wizard(drawer).steps_processor }
        .to raise_error(DfE::Wizard::InvalidGraph, /uses :student_visa\?, which is not listed in uses/)
    end
  end

  describe 'rule 5: nodes and edges only' do
    %i[root conditional_root before_next_step before_previous_step].each do |method_name|
      it "raises for #{method_name}" do
        drawer = lambda do |graph|
          graph.add_node :student, SubWizardSpecSteps::Student
          graph.public_send(method_name, :student)
        end

        expect { custom_wizard(drawer).steps_processor }
          .to raise_error(DfE::Wizard::InvalidGraph,
                          "sub-wizard :visa calls #{method_name}; a sub-wizard adds nodes and edges only")
      end
    end

    it 'raises for a nested sub-wizard' do
      drawer = lambda do |graph|
        graph.add_node :student, SubWizardSpecSteps::Student
        graph.add_sub_wizard :inner, steps: [:student]
      end

      expect { custom_wizard(drawer).steps_processor }
        .to raise_error(DfE::Wizard::InvalidGraph,
                        'sub-wizard :visa declares a sub-wizard; sub-wizards are one level only')
    end

    it 'raises for a node id that is already a node, before replacing it' do
      drawer = lambda do |graph|
        graph.add_node :start_date, SubWizardSpecSteps::Student
      end

      expect { custom_wizard(drawer).steps_processor }
        .to raise_error(DfE::Wizard::InvalidGraph, 'sub-wizard :visa adds :start_date, which is already a node')
    end

    it 'raises for an edge from a node the class did not add' do
      drawer = lambda do |graph|
        graph.add_node :student, SubWizardSpecSteps::Student
        graph.add_edge from: :funding, to: :student
      end

      expect { custom_wizard(drawer).steps_processor }
        .to raise_error(DfE::Wizard::InvalidGraph, 'sub-wizard :visa adds an edge from :funding, which it did not add')
    end
  end

  describe 'draw-time checks' do
    it 'passes the visa shape in both forms, with two entries from the parent' do
      expect { explicit_visa_wizard.steps_processor }.not_to raise_error
      expect { explicit_visa_wizard(exits: false, exit_to: :start_date).steps_processor }.not_to raise_error
      expect { class_visa_wizard.steps_processor }.not_to raise_error
    end

    it 'runs once per draw: once per wizard instance' do
      allow(DfE::Wizard::StepsProcessor::Graph::SubWizardChecks).to receive(:new).and_call_original

      wizard = class_visa_wizard
      wizard.find_step(:student)
      wizard.flow_path
      wizard.full_path
      class_visa_wizard.full_path

      expect(DfE::Wizard::StepsProcessor::Graph::SubWizardChecks).to have_received(:new).twice
    end

    describe 'rule 4: ids' do
      it 'raises when a sub-wizard id is a node id' do
        expect do
          build_wizard do |g|
            parent_nodes(g)
            visa_nodes(g)
            g.add_sub_wizard :funding, steps: %i[student]
          end.steps_processor
        end.to raise_error(DfE::Wizard::InvalidGraph, 'sub-wizard id :funding is also a node id; choose another id')
      end

      it 'raises when an explicit step is not a node' do
        expect do
          build_wizard do |g|
            parent_nodes(g)
            visa_nodes(g)
            g.add_sub_wizard :visa, steps: %i[student nope]
          end.steps_processor
        end.to raise_error(DfE::Wizard::InvalidGraph, 'sub-wizard :visa lists :nope, which is not a node')
      end
    end

    describe 'rule 3: one sub-wizard per step' do
      it 'raises when a step is in two sub-wizards' do
        expect do
          build_wizard do |g|
            parent_nodes(g)
            visa_nodes(g)
            visa_edges(g)
            g.add_sub_wizard :student_visa, steps: %i[student deadline_required deadline_at]
            g.add_sub_wizard :skilled_visa, steps: %i[skilled deadline_required]
            parent_edges(g)
          end.steps_processor
        end.to raise_error(DfE::Wizard::InvalidGraph,
                           ':deadline_required is in more than one sub-wizard (:student_visa, :skilled_visa)')
      end
    end

    describe 'rule 2: one exit target' do
      it 'raises when the steps exit to two targets' do
        expect do
          build_wizard do |g|
            parent_nodes(g)
            visa_nodes(g)
            visa_edges(g, exits: false)
            g.add_edge from: :student, to: :start_date
            g.add_edge from: :skilled, to: :review
            g.add_edge from: :deadline_required, to: :start_date
            g.add_edge from: :deadline_at, to: :start_date
            g.add_sub_wizard :visa, steps: visa_steps
            parent_edges(g)
          end.steps_processor
        end.to raise_error(DfE::Wizard::InvalidGraph,
                           'sub-wizard :visa exits to :start_date, :review; ' \
                           'a sub-wizard has one exit target (see exit_to:)')
      end

      it 'raises when a class names a parent node other than exit_to' do
        sub_wizard = Class.new do
          extend DfE::Wizard::SubWizard

          uses(*SubWizardSpecVisa.uses)

          def self.draw(graph)
            SubWizardSpecVisa.draw(graph)
            graph.add_edge from: :deadline_at, to: :review
          end
        end

        expect { class_visa_wizard(sub_wizard:).steps_processor }
          .to raise_error(DfE::Wizard::InvalidGraph,
                          'sub-wizard :visa exits to :start_date, :review; ' \
                          'a sub-wizard has one exit target (see exit_to:)')
      end

      it 'passes a sub-wizard with no exit (the end of the wizard)' do
        expect do
          build_wizard do |g|
            g.add_node :a, SubWizardSpecSteps::Start
            g.add_node :b, SubWizardSpecSteps::Review
            g.root :a
            g.add_edge from: :a, to: :b
            g.add_sub_wizard :tail, steps: %i[a b]
          end.steps_processor
        end.not_to raise_error
      end
    end

    describe 'rule 1: contiguous' do
      it 'raises when a path leaves the sub-wizard and comes back' do
        expect do
          build_wizard do |g|
            g.add_node :a, SubWizardSpecSteps::Start
            g.add_node :b, SubWizardSpecSteps::Funding
            g.add_node :c, SubWizardSpecSteps::Review
            g.root :a
            g.add_edge from: :a, to: :b
            g.add_edge from: :b, to: :c
            g.add_sub_wizard :split, steps: %i[a c]
          end.steps_processor
        end.to raise_error(DfE::Wizard::InvalidGraph,
                           'sub-wizard :split is not contiguous: a path leaves it, reaches :b and comes back to :c')
      end

      it 'raises for a loop from outside back into the sub-wizard' do
        expect do
          build_wizard do |g|
            g.add_node :a, SubWizardSpecSteps::Funding
            g.add_node :b, SubWizardSpecSteps::Review
            g.root :a
            g.add_edge from: :a, to: :b
            g.add_conditional_edge from: :b, when: :salaried?, then: :a, else: nil
            g.add_sub_wizard :loop, steps: [:a]
          end.steps_processor
        end.to raise_error(DfE::Wizard::InvalidGraph, /sub-wizard :loop is not contiguous/)
      end

      it "follows a custom edge's potential_transitions" do
        expect do
          build_wizard do |g|
            g.add_node :a, SubWizardSpecSteps::Funding
            g.add_node :b, SubWizardSpecSteps::Review
            g.root :a
            g.add_edge from: :a, to: :b
            g.add_custom_branching_edge(
              from: :b, conditional: -> {}, potential_transitions: [{ label: 'again', nodes: [:a] }],
            )
            g.add_sub_wizard :loop, steps: [:a]
          end.steps_processor
        end.to raise_error(DfE::Wizard::InvalidGraph, /sub-wizard :loop is not contiguous/)
      end
    end
  end
end
