module DfE
  module Wizard
    module StepsProcessor
      class Graph < Base
        # Stores all graph definition data: nodes, edges, callbacks, root node.
        #
        # Registry is a passive data structure - it stores but doesn't evaluate.
        # Use NavigationResolver to evaluate predicates and resolve paths.
        #
        # @api private
        class Registry
          # Node definition
          Node = Struct.new(:id, :klass, :skippable?, :skip_when, keyword_init: true)

          # Simple unconditional edge
          Edge = Struct.new(:from, :to, keyword_init: true)

          # Binary conditional edge (if/else)
          ConditionalEdge = Struct.new(:from, :when, :when_original, :then, :else, :label, keyword_init: true)

          # N-way conditional edge (multiple branches)
          MultipleConditionalEdge = Struct.new(:from, :branches, :default, :label, keyword_init: true)

          # Custom branching edge for arbitrary logic
          CustomBranchingEdge = Struct.new(:from, :conditional, :potential_transitions, keyword_init: true)

          attr_reader :nodes, :edges, :conditional_edges, :multiple_conditional_edges, :custom_branching_edges,
                      :step_labels
          attr_accessor :root_node, :conditional_root_method, :conditional_root_block, :potential_root_nodes

          def initialize
            @nodes = {}
            @edges = []
            @conditional_edges = []
            @multiple_conditional_edges = []
            @custom_branching_edges = []
            @root_node = nil
            @conditional_root_method = nil
            @conditional_root_block = nil
            @next_step_before_callbacks = []
            @previous_step_before_callbacks = []
            @step_labels = {}
            @potential_root_nodes = []
          end

          def add_node(node_id, klass, label: nil, skip_when: nil)
            @nodes[node_id] = Node.new(id: node_id, klass: klass, skip_when:, skippable?: skip_when.present?)
            @step_labels[node_id] = label || humanize(node_id)
          end

          def add_edge(from:, to:)
            @edges << Edge.new(from: from, to: to)
          end

          def add_conditional_edge(from:, when_predicate:, when_original:, then_step:, else_step:, label: nil)
            @conditional_edges << ConditionalEdge.new(
              from: from,
              when_original:,
              when: when_predicate,
              then: then_step,
              else: else_step,
              label: label,
            )
          end

          def add_multiple_conditional_edge(from:, branches:, default: nil, label: nil)
            @multiple_conditional_edges << MultipleConditionalEdge.new(
              from: from,
              branches: branches,
              default: default,
              label: label,
            )
          end

          def add_custom_branching_edge(from:, conditional:, potential_transitions:)
            @custom_branching_edges << CustomBranchingEdge.new(
              from: from,
              conditional: conditional,
              potential_transitions: potential_transitions,
            )
          end

          def add_before_next_callback(callback)
            @next_step_before_callbacks << callback
          end

          def add_before_previous_callback(callback)
            @previous_step_before_callbacks << callback
          end

          def before_next_callbacks
            @next_step_before_callbacks
          end

          def before_previous_callbacks
            @previous_step_before_callbacks
          end

          private

          def humanize(node_id)
            node_id.to_s.split('_').map(&:capitalize).join(' ')
          end
        end
      end
    end
  end
end
