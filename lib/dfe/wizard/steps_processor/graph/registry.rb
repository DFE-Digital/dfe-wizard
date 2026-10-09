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
          Node = Struct.new(:id, :klass, :skippable?, :skip_when, :depends_on, keyword_init: true)

          # Simple unconditional edge
          Edge = Struct.new(:from, :to, keyword_init: true)

          # Binary conditional edge (if/else)
          ConditionalEdge = Struct.new(:from, :when, :when_original, :then, :else, :label, keyword_init: true)

          # N-way conditional edge (multiple branches)
          MultipleConditionalEdge = Struct.new(:from, :branches, :default, :label, keyword_init: true)

          # Custom branching edge for arbitrary logic
          CustomBranchingEdge = Struct.new(:from, :conditional, :potential_transitions, keyword_init: true)

          # A unit of steps: a declared sub-wizard, or a single-step unit
          # built by Graph#unit_for. The steps are nodes of this graph.
          #
          # @!attribute id [Symbol] Sub-wizard id, or the step id for a single-step unit
          # @!attribute step_ids [Array<Symbol>] The unit's steps, in declaration or draw order
          # @!attribute exit_to [Symbol, nil] Where open exits go
          # @!attribute uses [Array<Symbol>] State store methods a class form calls
          # @!attribute source [Object, nil] The class form object, or nil
          # @!attribute depends_on [Array<Symbol>] Answers whose change queues this unit in a change journey
          # @api public
          Unit = Struct.new(:id, :step_ids, :exit_to, :uses, :source, :depends_on, keyword_init: true)

          attr_reader :nodes, :edges, :conditional_edges, :multiple_conditional_edges, :custom_branching_edges,
                      :step_labels, :sub_wizards
          attr_accessor :root_node, :conditional_root_method, :conditional_root_block, :potential_root_nodes,
                        :check_answers_node

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
            @sub_wizards = {}
          end

          def add_node(node_id, klass, label: nil, skip_when: nil, depends_on: [])
            @nodes[node_id] = Node.new(
              id: node_id, klass: klass, skip_when:, skippable?: skip_when.present?, depends_on: depends_on.freeze,
            )
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

          def add_sub_wizard(unit)
            @sub_wizards[unit.id] = unit
          end

          # The sub-wizard that holds a step
          #
          # @param step_id [Symbol]
          # @return [Unit, nil]
          def sub_wizard_for(step_id)
            @sub_wizards.each_value.find { |unit| unit.step_ids.include?(step_id) }
          end

          # Wire each sub-wizard's open exits to its exit_to node.
          #
          # Adds a simple edge to exit_to from every unit step that has no
          # simple edge. Simple edges are evaluated last, so the new edge is
          # the fallback when the step's other edges give nil, and the only
          # edge of a step that has none. A step's own simple edge is kept.
          #
          # @return [void]
          def wire_sub_wizard_exits
            @sub_wizards.each_value do |unit|
              next unless unit.exit_to

              unit.step_ids.each do |step_id|
                next if @edges.any? { |edge| edge.from == step_id }

                add_edge(from: step_id, to: unit.exit_to)
              end
            end
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
