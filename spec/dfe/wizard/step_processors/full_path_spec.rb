RSpec.describe DfE::Wizard::StepsProcessor::Graph, '#full_path' do
  module FullPathSteps
    class A
      include DfE::Wizard::Step

      attribute :choice, :string
    end

    class B
      include DfE::Wizard::Step
    end

    class C
      include DfE::Wizard::Step
    end

    class D
      include DfE::Wizard::Step
    end

    class Exit < DfE::Wizard::Core::Redirect; end
  end

  class FullPathStateStore
    include DfE::Wizard::StateStore

    def choice_b?
      read[:choice] == 'b'
    end

    def always?
      true
    end

    def raises_on_nil?
      read.fetch(:choice).present?
    end
  end

  def build_wizard(&draw)
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

    wizard_class.new(state_store: FullPathStateStore.new)
  end

  def nodes(graph, *ids)
    ids.each { |id| graph.add_node id, FullPathSteps.const_get(id.to_s.upcase) }
  end

  describe 'where the walk ends' do
    it 'includes the last step when there is no next step' do
      wizard = build_wizard do |g|
        nodes(g, :a, :b, :c)
        g.root :a
        g.add_edge from: :a, to: :b
        g.add_edge from: :b, to: :c
      end

      expect(wizard.steps_processor.full_path).to eq(%i[a b c])
    end

    it 'does not stop at the current step' do
      wizard = build_wizard do |g|
        nodes(g, :a, :b, :c)
        g.root :a
        g.add_edge from: :a, to: :b
        g.add_edge from: :b, to: :c
      end
      wizard.current_step_name = :a

      expect(wizard.full_path).to eq(%i[a b c])
    end

    it 'stops before a Redirect node' do
      wizard = build_wizard do |g|
        nodes(g, :a, :b)
        g.add_node :exit, DfE::Wizard::Core::Redirect
        g.root :a
        g.add_edge from: :a, to: :b
        g.add_edge from: :b, to: :exit
      end

      expect(wizard.full_path).to eq(%i[a b])
    end

    it 'stops before a node whose class is a Redirect subclass' do
      wizard = build_wizard do |g|
        nodes(g, :a)
        g.add_node :exit, FullPathSteps::Exit
        g.root :a
        g.add_edge from: :a, to: :exit
      end

      expect(wizard.full_path).to eq(%i[a])
    end

    it 'stops before a next id that is not a node' do
      wizard = build_wizard do |g|
        nodes(g, :a, :b)
        g.root :a
        g.add_edge from: :a, to: :b
        g.add_edge from: :b, to: :course_edit
      end

      expect(wizard.full_path).to eq(%i[a b])
    end

    it 'stops before a repeated step' do
      wizard = build_wizard do |g|
        nodes(g, :a, :b)
        g.root :a
        g.add_edge from: :a, to: :b
        g.add_edge from: :b, to: :a
      end

      expect(wizard.full_path).to eq(%i[a b])
    end

    it 'returns the path so far at a skip_when loop' do
      wizard = build_wizard do |g|
        nodes(g, :a)
        g.add_node :b, FullPathSteps::B, skip_when: :always?
        g.add_node :c, FullPathSteps::C, skip_when: :always?
        g.root :a
        g.add_edge from: :a, to: :b
        g.add_edge from: :b, to: :c
        g.add_edge from: :c, to: :b
      end

      expect(wizard.full_path).to eq(%i[a])
    end

    it 'returns the path so far at a dead end with default: nil' do
      wizard = build_wizard do |g|
        nodes(g, :a, :b)
        g.root :a
        g.add_multiple_conditional_edges(
          from: :a,
          branches: [{ when: :choice_b?, then: :b }],
          default: nil,
        )
      end

      expect(wizard.full_path).to eq(%i[a])
    end

    it 'returns [] when a conditional root resolves to an id that is not a node' do
      wizard = build_wizard do |g|
        nodes(g, :a)
        g.conditional_root(potential_root: %i[a]) do |store|
          store.read[:choice] == 'gone' ? :missing : :a
        end
      end
      wizard.state_store.write(choice: 'gone')

      expect(wizard.full_path).to eq([])
    end
  end

  describe 'how the walk moves' do
    it 'applies skip_when to later steps but not to the root' do
      wizard = build_wizard do |g|
        g.add_node :a, FullPathSteps::A, skip_when: :always?
        g.add_node :b, FullPathSteps::B, skip_when: :always?
        nodes(g, :c)
        g.root :a
        g.add_edge from: :a, to: :b
        g.add_edge from: :b, to: :c
      end

      expect(wizard.full_path).to eq(%i[a c])
    end

    it 'runs no callbacks' do
      wizard = build_wizard do |g|
        nodes(g, :a, :b)
        g.root :a
        g.add_edge from: :a, to: :b
        g.before_next_step { raise 'before_next_step ran' }
        g.before_previous_step { raise 'before_previous_step ran' }
      end

      expect(wizard.full_path).to eq(%i[a b])
    end

    it 'takes the branch the predicates give for an unanswered step, and follows the current answers' do
      wizard = build_wizard do |g|
        nodes(g, :a, :b, :c, :d)
        g.root :a
        g.add_conditional_edge(from: :a, when: :choice_b?, then: :b, else: :c)
        g.add_edge from: :b, to: :d
        g.add_edge from: :c, to: :d
      end

      expect(wizard.full_path).to eq(%i[a c d])

      wizard.state_store.write(choice: 'b')
      expect(wizard.full_path).to eq(%i[a b d])
    end

    it 'starts at a conditional root' do
      wizard = build_wizard do |g|
        nodes(g, :a, :b, :c)
        g.conditional_root(potential_root: %i[a b]) do |store|
          store.read[:choice] == 'b' ? :b : :a
        end
        g.add_edge from: :a, to: :b
        g.add_edge from: :b, to: :c
      end

      expect(wizard.full_path).to eq(%i[a b c])

      wizard.state_store.write(choice: 'b')
      expect(wizard.full_path).to eq(%i[b c])
    end

    it 'lets an error from a predicate propagate' do
      wizard = build_wizard do |g|
        nodes(g, :a, :b, :c)
        g.root :a
        g.add_conditional_edge(from: :a, when: :raises_on_nil?, then: :b, else: :c)
      end

      expect { wizard.full_path }.to raise_error(KeyError)
    end
  end

  describe 'existing paths are unchanged' do
    it 'keeps flow_path, path_traversal and dfs_path as in 1.0' do
      wizard = build_wizard do |g|
        nodes(g, :a, :b)
        g.add_node :exit, DfE::Wizard::Core::Redirect
        g.root :a
        g.add_edge from: :a, to: :b
        g.add_edge from: :b, to: :exit
      end
      graph = wizard.steps_processor

      expect(wizard.flow_path(:exit)).to eq(%i[a b exit])
      expect(wizard.flow_path(:b)).to eq(%i[a b])
      expect(graph.path_traversal(:missing)).to eq([])
      expect(graph.resolver.dfs_path(:a, :exit, Set.new, max_depth: 3)).to eq(%i[a b exit])
    end

    it 'keeps flow_path empty for a loop and a dead end' do
      loop_wizard = build_wizard do |g|
        nodes(g, :a, :b, :c)
        g.root :a
        g.add_edge from: :a, to: :b
        g.add_edge from: :b, to: :a
      end
      dead_end_wizard = build_wizard do |g|
        nodes(g, :a, :b)
        g.root :a
        g.add_multiple_conditional_edges(from: :a, branches: [{ when: :choice_b?, then: :b }], default: nil)
      end

      expect(loop_wizard.flow_path(:c)).to eq([])
      expect(dead_end_wizard.flow_path(:b)).to eq([])
    end
  end

  describe 'a wizard whose steps processor is Linear' do
    it 'raises NotImplementedError through wizard.full_path' do
      wizard_class = Class.new do
        include DfE::Wizard

        def steps_processor
          DfE::Wizard::StepsProcessor::Linear.draw(self) do |linear|
            linear.add_step :a, FullPathSteps::A
          end
        end

        def logger
          nil
        end

        def route_strategy
          nil
        end
      end
      wizard = wizard_class.new(state_store: FullPathStateStore.new)

      expect { wizard.full_path }.to raise_error(NotImplementedError, 'full_path needs StepsProcessor::Graph')
    end
  end
end
