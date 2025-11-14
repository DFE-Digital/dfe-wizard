# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DfE::Wizard::StepsProcessor::Graph do
  def build_test_wizard(current_step_name, state_data = {}, predicate_results = {})
    state_store = instance_double('StateStore', step_data: proc { |step_id| state_data.dig(:steps, step_id) || {} })

    wizard_class = Class.new do
      attr_accessor :current_step_name, :state_store, :predicate_results

      def initialize(step_name, store, predicates)
        @current_step_name = step_name
        @state_store = store
        @predicate_results = predicates
      end

      def step(step_name)
        OpenStruct.new(id: step_name)
      end

      def method_missing(method_name, *args)
        if @predicate_results.key?(method_name)
          @predicate_results[method_name]
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        @predicate_results.key?(method_name) || super
      end
    end

    wizard_class.new(current_step_name, state_store, predicate_results)
  end

  let(:step_a_class) { Class.new }
  let(:step_b_class) { Class.new }
  let(:step_c_class) { Class.new }
  let(:step_d_class) { Class.new }
  let(:step_review_class) { Class.new }

  describe '.draw' do
    let(:wizard) { build_test_wizard(:step_a, {}, {}) }

    context 'validation' do
      it 'raises ArgumentError if no block given' do
        expect {
          described_class.draw(wizard)
        }.to raise_error(ArgumentError, /A block must be given/)
      end

      it 'raises ArgumentError if root node not set after block executes' do
        expect {
          described_class.draw(wizard) do |g|
            g.add_node(:step_a, step_a_class)
          end
        }.to raise_error(ArgumentError, /Graph must have a root node set/)
      end

      it 'does not raise when root node is properly set' do
        expect {
          described_class.draw(wizard) do |g|
            g.root(:step_a)
            g.add_node(:step_a, step_a_class)
          end
        }.not_to raise_error
      end
    end

    context 'graph construction' do
      it 'returns a Graph instance' do
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.root(:step_a)
        end
        expect(graph).to be_a(described_class)
      end

      it 'yields the graph instance to the block' do
        expect { |b|
          described_class.draw(wizard) do |g|
            g.add_node(:step_a, step_a_class)
            g.root(:step_a)
            b.to_proc.call(g)
          end
        }.to yield_with_args(described_class)
      end

      it 'sets the wizard instance' do
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.root(:step_a)
        end
        expect(graph.instance_variable_get(:@wizard)).to eq(wizard)
      end
    end
  end

  describe '#add_node and #find_step' do
    let(:wizard) { build_test_wizard(:step_a, {}, {}) }

    it 'adds a node to the graph' do
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.root(:step_a)
      end

      expect(graph.nodes[:step_a]).to be_a(DfE::Wizard::StepsProcessor::Graph::Node)
      expect(graph.nodes[:step_a].id).to eq(:step_a)
      expect(graph.nodes[:step_a].klass).to eq(step_a_class)
    end

    it 'stores multiple nodes' do
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.add_node(:step_c, step_c_class)
        g.root(:step_a)
      end

      expect(graph.nodes.keys).to contain_exactly(:step_a, :step_b, :step_c)
    end

    it 'finds a step class by node id' do
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.root(:step_a)
      end

      expect(graph.find_step(:step_a)).to eq(step_a_class)
      expect(graph.find_step(:step_b)).to eq(step_b_class)
    end

    it 'returns nil for non-existent step' do
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.root(:step_a)
      end

      expect(graph.find_step(:missing)).to be_nil
    end
  end

  describe '#root' do
    let(:wizard) { build_test_wizard(:step_a, {}, {}) }

    it 'sets the root node' do
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.root(:step_a)
      end

      expect(graph.root_node).to eq(:step_a)
    end

    it 'allows changing root node' do
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.root(:step_a)
        g.root(:step_b)
      end

      expect(graph.root_node).to eq(:step_b)
    end
  end

  describe '#add_edge' do
    let(:wizard) { build_test_wizard(:step_a, {}, {}) }

    it 'creates a simple edge between two nodes' do
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.add_edge(from: :step_a, to: :step_b)
        g.root(:step_a)
      end

      expect(graph.edges.size).to eq(1)
      expect(graph.edges.first.from).to eq(:step_a)
      expect(graph.edges.first.to).to eq(:step_b)
    end

    it 'creates multiple edges for a linear path' do
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.add_node(:step_c, step_c_class)
        g.add_edge(from: :step_a, to: :step_b)
        g.add_edge(from: :step_b, to: :step_c)
        g.root(:step_a)
      end

      expect(graph.edges.size).to eq(2)
      expect(graph.edges.map(&:from)).to eq(%i[step_a step_b])
      expect(graph.edges.map(&:to)).to eq(%i[step_b step_c])
    end
  end

  describe '#add_conditional_edge' do
    let(:wizard) { build_test_wizard(:step_a, {}, { is_eligible?: true }) }

    it 'creates a conditional edge' do
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.add_node(:step_c, step_c_class)
        g.add_conditional_edge(
          from: :step_a,
          when: :is_eligible?,
          then: :step_b,
          else: :step_c,
          label: 'Eligibility check',
        )
        g.root(:step_a)
      end

      expect(graph.conditional_edges.size).to eq(1)
      edge = graph.conditional_edges.first
      expect(edge.from).to eq(:step_a)
      expect(edge.then).to eq(:step_b)
      expect(edge.else).to eq(:step_c)
      expect(edge.label).to eq('Eligibility check')
    end

    it 'accepts a proc as predicate' do
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.add_node(:step_c, step_c_class)
        g.add_conditional_edge(
          from: :step_a,
          when: proc { |_step| true },
          then: :step_b,
          else: :step_c,
        )
        g.root(:step_a)
      end

      expect(graph.conditional_edges.size).to eq(1)
      expect(graph.conditional_edges.first.when).to be_a(Proc)
    end

    it 'stores multiple conditional edges' do
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.add_node(:step_c, step_c_class)
        g.add_node(:step_d, step_d_class)
        g.add_conditional_edge(from: :step_a, when: :is_eligible?, then: :step_b, else: :step_c)
        g.add_conditional_edge(from: :step_b, when: :another_check?, then: :step_c, else: :step_d)
        g.root(:step_a)
      end

      expect(graph.conditional_edges.size).to eq(2)
    end
  end

  describe '#add_custom_branching_edge' do
    let(:wizard) { build_test_wizard(:step_a, {}, {}) }

    it 'creates a custom branching edge' do
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.add_node(:step_c, step_c_class)
        g.add_custom_branching_edge(
          from: :step_a,
          conditional: proc { |_step| :step_b },
          potential_transitions: [
            { label: 'Path 1', nodes: [:step_b] },
            { label: 'Path 2', nodes: [:step_c] },
          ],
        )
        g.root(:step_a)
      end

      expect(graph.custom_branching_edges.size).to eq(1)
      edge = graph.custom_branching_edges.first
      expect(edge.from).to eq(:step_a)
      expect(edge.conditional).to be_a(Proc)
      expect(edge.potential_transitions.size).to eq(2)
    end
  end

  describe '#next_step_without_callbacks' do
    context 'with simple linear edges' do
      it 'follows linear path' do
        wizard = build_test_wizard(:step_a, {}, {})
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_node(:step_c, step_c_class)
          g.add_edge(from: :step_a, to: :step_b)
          g.add_edge(from: :step_b, to: :step_c)
          g.root(:step_a)
        end

        expect(graph.next_step_without_callbacks(:step_a)).to eq(:step_b)
        expect(graph.next_step_without_callbacks(:step_b)).to eq(:step_c)
      end

      it 'returns nil when no edge exists' do
        wizard = build_test_wizard(:step_b, {}, {})
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_edge(from: :step_a, to: :step_b)
          g.root(:step_a)
        end

        expect(graph.next_step_without_callbacks(:step_b)).to be_nil
      end

      it 'uses current_step_name when no argument given' do
        wizard = build_test_wizard(:step_a, {}, {})
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_edge(from: :step_a, to: :step_b)
          g.root(:step_a)
        end

        expect(graph.next_step_without_callbacks).to eq(:step_b)
      end
    end

    context 'with conditional edges' do
      it 'follows then branch when condition is true' do
        wizard = build_test_wizard(:step_a, {}, { is_uk?: true })
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_node(:step_c, step_c_class)
          g.add_conditional_edge(
            from: :step_a,
            when: :is_uk?,
            then: :step_b,
            else: :step_c,
          )
          g.root(:step_a)
        end

        expect(graph.next_step_without_callbacks(:step_a)).to eq(:step_b)
      end

      it 'follows else branch when condition is false' do
        wizard = build_test_wizard(:step_a, {}, { is_uk?: false })
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_node(:step_c, step_c_class)
          g.add_conditional_edge(
            from: :step_a,
            when: :is_uk?,
            then: :step_b,
            else: :step_c,
          )
          g.root(:step_a)
        end

        expect(graph.next_step_without_callbacks(:step_a)).to eq(:step_c)
      end

      it 'evaluates proc predicates' do
        wizard = build_test_wizard(:step_a, {}, {})
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_node(:step_c, step_c_class)
          g.add_conditional_edge(
            from: :step_a,
            when: proc { |_step| true },
            then: :step_b,
            else: :step_c,
          )
          g.root(:step_a)
        end

        expect(graph.next_step_without_callbacks(:step_a)).to eq(:step_b)
      end
    end

    context 'with custom branching edges' do
      it 'evaluates custom branching logic' do
        wizard = build_test_wizard(:step_a, {}, {})
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_node(:step_c, step_c_class)
          g.add_custom_branching_edge(
            from: :step_a,
            conditional: proc { |_step| :step_c },
            potential_transitions: [{ label: 'Custom', nodes: %i[step_b step_c] }],
          )
          g.root(:step_a)
        end

        expect(graph.next_step_without_callbacks(:step_a)).to eq(:step_c)
      end
    end

    context 'edge priority' do
      it 'prioritizes custom branching over conditional over simple edges' do
        wizard = build_test_wizard(:step_a, {}, { check?: true })
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_node(:step_c, step_c_class)
          g.add_node(:step_d, step_d_class)
          g.add_edge(from: :step_a, to: :step_b)
          g.add_conditional_edge(from: :step_a, when: :check?, then: :step_c, else: :step_d)
          g.add_custom_branching_edge(
            from: :step_a,
            conditional: proc { |_step| :step_d },
            potential_transitions: [{ label: 'Custom', nodes: [:step_d] }],
          )
          g.root(:step_a)
        end

        expect(graph.next_step_without_callbacks(:step_a)).to eq(:step_d)
      end
    end
  end

  describe '#previous_step_without_callbacks' do
    context 'linear wizard' do
      it 'returns previous step in path' do
        wizard = build_test_wizard(:step_b, {}, {})
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_node(:step_c, step_c_class)
          g.add_edge(from: :step_a, to: :step_b)
          g.add_edge(from: :step_b, to: :step_c)
          g.root(:step_a)
        end

        expect(graph.previous_step_without_callbacks(:step_b)).to eq(:step_a)
        expect(graph.previous_step_without_callbacks(:step_c)).to eq(:step_b)
      end

      it 'returns nil for root node' do
        wizard = build_test_wizard(:step_a, {}, {})
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_edge(from: :step_a, to: :step_b)
          g.root(:step_a)
        end

        expect(graph.previous_step_without_callbacks(:step_a)).to be_nil
      end

      it 'uses current_step_name when no argument given' do
        wizard = build_test_wizard(:step_b, {}, {})
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_edge(from: :step_a, to: :step_b)
          g.root(:step_a)
        end

        expect(graph.previous_step_without_callbacks).to eq(:step_a)
      end
    end

    context 'conditional wizard' do
      it 'returns previous step respecting conditions' do
        wizard = build_test_wizard(:step_c, {}, { is_eligible?: true })
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_node(:step_c, step_c_class)
          g.add_conditional_edge(from: :step_a, when: :is_eligible?, then: :step_b, else: :step_c)
          g.add_edge(from: :step_b, to: :step_c)
          g.root(:step_a)
        end

        expect(graph.previous_step_without_callbacks(:step_c)).to eq(:step_b)
      end

      it 'handles skipped steps (direct path)' do
        wizard = build_test_wizard(:step_c, {}, { is_eligible?: false })
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_node(:step_c, step_c_class)
          g.add_conditional_edge(from: :step_a, when: :is_eligible?, then: :step_b, else: :step_c)
          g.root(:step_a)
        end

        expect(graph.previous_step_without_callbacks(:step_c)).to eq(:step_a)
      end
    end
  end

  describe '#path_traversal' do
    context 'linear path' do
      let(:wizard) { build_test_wizard(:step_a, {}, {}) }

      it 'returns full path to target' do
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_node(:step_c, step_c_class)
          g.add_edge(from: :step_a, to: :step_b)
          g.add_edge(from: :step_b, to: :step_c)
          g.root(:step_a)
        end

        expect(graph.path_traversal(:step_c)).to eq(%i[step_a step_b step_c])
      end

      it 'returns partial path' do
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_node(:step_c, step_c_class)
          g.add_edge(from: :step_a, to: :step_b)
          g.add_edge(from: :step_b, to: :step_c)
          g.root(:step_a)
        end

        expect(graph.path_traversal(:step_b)).to eq(%i[step_a step_b])
      end

      it 'returns empty array for unreachable target' do
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_node(:step_c, step_c_class)
          g.add_edge(from: :step_a, to: :step_b)
          g.root(:step_a)
        end

        expect(graph.path_traversal(:step_c)).to eq([])
      end

      it 'uses current_step_name when no target given' do
        wizard = build_test_wizard(:step_b, {}, {})
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_edge(from: :step_a, to: :step_b)
          g.root(:step_a)
        end

        expect(graph.path_traversal).to eq(%i[step_a step_b])
      end
    end

    context 'conditional path' do
      it 'follows conditional branches (then path)' do
        wizard = build_test_wizard(:step_a, {}, { is_uk?: true })
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_node(:step_c, step_c_class)
          g.add_node(:step_review, step_review_class)
          g.add_conditional_edge(from: :step_a, when: :is_uk?, then: :step_review, else: :step_b)
          g.add_edge(from: :step_b, to: :step_c)
          g.add_edge(from: :step_c, to: :step_review)
          g.root(:step_a)
        end

        expect(graph.path_traversal(:step_review)).to eq(%i[step_a step_review])
      end

      it 'follows else branch' do
        wizard = build_test_wizard(:step_a, {}, { is_uk?: false })
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_node(:step_c, step_c_class)
          g.add_node(:step_review, step_review_class)
          g.add_conditional_edge(from: :step_a, when: :is_uk?, then: :step_review, else: :step_b)
          g.add_edge(from: :step_b, to: :step_c)
          g.add_edge(from: :step_c, to: :step_review)
          g.root(:step_a)
        end

        expect(graph.path_traversal(:step_review)).to eq(%i[step_a step_b step_c step_review])
      end
    end

    context 'cycle detection' do
      it 'stops at depth limit to prevent infinite loops' do
        wizard = build_test_wizard(:step_a, {}, {})
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_edge(from: :step_a, to: :step_b)
          g.add_edge(from: :step_b, to: :step_a)
          g.root(:step_a)
        end

        result = graph.path_traversal(:step_c)
        expect(result).to eq([])
      end

      it 'stops on revisiting same node' do
        wizard = build_test_wizard(:step_a, {}, {})
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_edge(from: :step_a, to: :step_b)
          g.add_edge(from: :step_b, to: :step_a)
          g.root(:step_a)
        end

        result = graph.path_traversal(:step_a)
        expect(result).to eq([:step_a])
      end
    end
  end

  describe '#before_next_step callbacks' do
    let(:wizard) { build_test_wizard(:step_a, {}, {}) }

    it 'executes callback before next_step' do
      callback_called = false
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.add_edge(from: :step_a, to: :step_b)
        g.before_next_step {
          callback_called = true
          nil
        }
        g.root(:step_a)
      end

      graph.next_step(:step_a)
      expect(callback_called).to be true
    end

    it 'uses callback return value if not nil' do
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.add_node(:step_c, step_c_class)
        g.add_edge(from: :step_a, to: :step_b)
        g.before_next_step { :step_c }
        g.root(:step_a)
      end

      expect(graph.next_step(:step_a)).to eq(:step_c)
    end

    it 'falls back to normal navigation if callback returns nil' do
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.add_edge(from: :step_a, to: :step_b)
        g.before_next_step { nil }
        g.root(:step_a)
      end

      expect(graph.next_step(:step_a)).to eq(:step_b)
    end

    it 'executes multiple callbacks in order' do
      call_order = []
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.add_edge(from: :step_a, to: :step_b)
        g.before_next_step {
          call_order << 1
          nil
        }
        g.before_next_step {
          call_order << 2
          nil
        }
        g.root(:step_a)
      end

      graph.next_step(:step_a)
      expect(call_order).to eq([1, 2])
    end

    it 'accepts method names as callbacks' do
      callback_called = false
      wizard_with_method = build_test_wizard(:step_a, {}, {})
      wizard_with_method.define_singleton_method(:my_callback) {
        callback_called = true
        nil
      }

      graph = described_class.draw(wizard_with_method) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.add_edge(from: :step_a, to: :step_b)
        g.before_next_step(:my_callback)
        g.root(:step_a)
      end

      graph.next_step(:step_a)
      expect(callback_called).to be true
    end
  end

  describe '#before_previous_step callbacks' do
    let(:wizard) { build_test_wizard(:step_b, {}, {}) }

    it 'executes callback before previous_step' do
      callback_called = false
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.add_edge(from: :step_a, to: :step_b)
        g.before_previous_step {
          callback_called = true
          nil
        }
        g.root(:step_a)
      end

      graph.previous_step(:step_b)
      expect(callback_called).to be true
    end

    it 'uses callback return value if not nil' do
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.add_node(:step_c, step_c_class)
        g.add_edge(from: :step_a, to: :step_b)
        g.before_previous_step { :step_c }
        g.root(:step_a)
      end

      expect(graph.previous_step(:step_b)).to eq(:step_c)
    end

    it 'falls back to normal navigation if callback returns nil' do
      graph = described_class.draw(wizard) do |g|
        g.add_node(:step_a, step_a_class)
        g.add_node(:step_b, step_b_class)
        g.add_edge(from: :step_a, to: :step_b)
        g.before_previous_step { nil }
        g.root(:step_a)
      end

      expect(graph.previous_step(:step_b)).to eq(:step_a)
    end
  end

  describe 'complex wizard scenarios' do
    context 'nationality wizard (UK vs non-UK path)' do
      it 'handles UK national path (short path)' do
        wizard = build_test_wizard(:nationality, {}, { uk_or_irish?: true })
        graph = described_class.draw(wizard) do |g|
          g.add_node(:name, step_a_class)
          g.add_node(:nationality, step_b_class)
          g.add_node(:right_to_work, step_c_class)
          g.add_node(:review, step_review_class)
          g.add_edge(from: :name, to: :nationality)
          g.add_conditional_edge(
            from: :nationality,
            when: :uk_or_irish?,
            then: :review,
            else: :right_to_work,
          )
          g.add_edge(from: :right_to_work, to: :review)
          g.root(:name)
        end

        expect(graph.path_traversal(:review)).to eq(%i[name nationality review])
        expect(graph.previous_step_without_callbacks(:review)).to eq(:nationality)
      end

      it 'handles non-UK national path (long path)' do
        wizard = build_test_wizard(:nationality, {}, { uk_or_irish?: false })
        graph = described_class.draw(wizard) do |g|
          g.add_node(:name, step_a_class)
          g.add_node(:nationality, step_b_class)
          g.add_node(:right_to_work, step_c_class)
          g.add_node(:review, step_review_class)
          g.add_edge(from: :name, to: :nationality)
          g.add_conditional_edge(
            from: :nationality,
            when: :uk_or_irish?,
            then: :review,
            else: :right_to_work,
          )
          g.add_edge(from: :right_to_work, to: :review)
          g.root(:name)
        end

        expect(graph.path_traversal(:review)).to eq(%i[name nationality right_to_work review])
        expect(graph.previous_step_without_callbacks(:review)).to eq(:right_to_work)
      end
    end

    context 'multi-conditional wizard (nested conditions)' do
      it 'handles nested conditionals' do
        wizard = build_test_wizard(:step_a, {}, { check_a?: true, check_b?: false })
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_node(:step_c, step_c_class)
          g.add_node(:step_d, step_d_class)
          g.add_node(:review, step_review_class)
          g.add_conditional_edge(from: :step_a, when: :check_a?, then: :step_b, else: :step_c)
          g.add_conditional_edge(from: :step_b, when: :check_b?, then: :step_d, else: :review)
          g.add_edge(from: :step_c, to: :review)
          g.root(:step_a)
        end

        expect(graph.path_traversal(:review)).to eq(%i[step_a step_b review])
      end
    end

    context 'diamond-shaped wizard (multiple paths converge)' do
      it 'handles convergent paths' do
        wizard = build_test_wizard(:step_a, {}, { path_choice?: true })
        graph = described_class.draw(wizard) do |g|
          g.add_node(:step_a, step_a_class)
          g.add_node(:step_b, step_b_class)
          g.add_node(:step_c, step_c_class)
          g.add_node(:step_d, step_d_class)
          g.add_conditional_edge(from: :step_a, when: :path_choice?, then: :step_b, else: :step_c)
          g.add_edge(from: :step_b, to: :step_d)
          g.add_edge(from: :step_c, to: :step_d)
          g.root(:step_a)
        end

        expect(graph.path_traversal(:step_d)).to eq(%i[step_a step_b step_d])
        expect(graph.next_step_without_callbacks(:step_b)).to eq(:step_d)
        expect(graph.next_step_without_callbacks(:step_c)).to eq(:step_d)
      end
    end
  end
end
