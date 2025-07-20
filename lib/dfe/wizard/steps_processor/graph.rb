# frozen_string_literal: true

module DfE
  module Wizard
    module StepsProcessor
      # A graph-based steps processor for multi-step wizards, supporting linear, conditional, and custom branching.
      #
      # Usage:
      #   DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
      #     graph.add_node :step1, StepOne
      #     ...
      #   end
      class Graph
        Node = Struct.new(:id, :klass, keyword_init: true)
        Edge = Struct.new(:from, :to, keyword_init: true)
        ConditionalEdge = Struct.new(:from, :when, :then, :else, :label, keyword_init: true)
        CustomBranchingEdge = Struct.new(:from, :conditional, :potential_transitions, keyword_init: true)

        attr_reader :nodes, :edges, :conditional_edges, :custom_branching_edges, :root_node

        # Builds a wizard graph, yielding the instance so the caller can add nodes/edges.
        #
        # @param wizard [Object] the wizard instance (for method predicates)
        # @yieldparam graph [Graph] this graph instance
        # @return [Graph]
        #
        # @example
        #   DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
        #     graph.add_node :a, StepA
        #     graph.root :a
        #     graph.add_edge :a, to: :b
        #   end
        def self.draw(wizard)
          graph = new(wizard)
          yield(graph) if block_given?
          graph
        end

        # @param wizard [Object] the wizard (used for symbolic predicates)
        def initialize(wizard)
          @wizard = wizard
          @nodes = {}
          @edges = []
          @conditional_edges = []
          @custom_branching_edges = []
          @root_node = nil
        end

        # Adds a step node to the graph.
        # @param node_id [Symbol]
        # @param klass [Class]
        def add_node(node_id, klass)
          @nodes[node_id] = Node.new(id: node_id, klass: klass)
        end

        # Sets the root (start) node for the graph.
        # @param node_id [Symbol]
        def root(node_id)
          @root_node = node_id
        end

        # Adds a simple linear edge.
        # @param from [Symbol]
        # @param to [Symbol]
        def add_edge(from:, to:)
          @edges << Edge.new(from: from, to: to)
        end

        # Adds a conditional (if/else) branching edge.
        # @param from [Symbol]
        # @param options [Hash]
        #   - :from [Symbol]
        #   - :when [Symbol, Proc] predicate
        #   - :then [Symbol] step id if predicate true
        #   - :else [Symbol] step id if predicate false
        #   - :label [String, nil] for diagramming
        def add_conditional_edge(**options)
          predicate = build_predicate(options[:when])
          @conditional_edges << ConditionalEdge.new(
            from: options[:from],
            when: predicate,
            then: options[:then],
            else: options[:else],
            label: options[:label],
          )
        end

        # Adds a custom branching edge for arbitrary step transitions.
        # @param from [Symbol]
        # @param conditional [Symbol, Proc]
        # @param potential_transitions [Array<Hash>] documentation only, e.g. { label:, nodes: }
        def add_custom_branching_edge(from:, conditional:, potential_transitions:)
          predicate = build_predicate(conditional)
          @custom_branching_edges << CustomBranchingEdge.new(
            from: from,
            conditional: predicate,
            potential_transitions: potential_transitions,
          )
        end

        # Returns the next step (symbol), given current step and data.
        def next_step(current_step = nil, data = nil)
          current_step ||= @wizard.current_step_name
          data ||= @wizard.data

          custom_edge = @custom_branching_edges.find { |e| e.from == current_step }
          if custom_edge
            return custom_edge.conditional.call(data)
          end

          cond_edge = @conditional_edges.find { |e| e.from == current_step }
          if cond_edge
            return cond_edge.when.call(data) ? cond_edge.then : cond_edge.else
          end

          edge = @edges.find { |e| e.from == current_step }
          edge&.to
        end

        # Returns the previous step symbol, or nil if at root.
        def previous_step(current_step = nil, data = nil)
          current_step ||= @wizard.current_step_name
          data ||= @wizard.data

          return nil if current_step == @root_node

          path = path_traversal(current_step, data)
          return nil if path.size < 2

          path[-2]
        end

        # Returns a traversal path through the user's wizard so far.
        def path_traversal(target_step = nil, data = nil)
          target_step ||= @wizard.current_step_name
          data ||= @wizard.data
          steps = []
          current = @root_node
          steps << current
          depth_limit = @nodes.size

          while current && current != target_step && steps.size < depth_limit
            n = next_step(current, data)
            break if n.nil? || steps.include?(n)

            steps << n
            current = n
          end

          steps.include?(target_step) ? steps : []
        end

        # Builds a Graphviz graph for visualization.
        def to_doc
          require 'ruby-graphviz'
          g = GraphViz.new(@wizard.class.name, rankdir: 'LR', fontname: 'Arial')
          g.node[:style] = 'rounded,filled'
          g.node[:shape] = 'rect'
          g.node[:color] = '#666666'
          g.node[:fillcolor] = '#f9f9f9'

          start_id = @root_node
          g.add_nodes(start_id.to_s, fillcolor: '#d2f7ef', color: '#00703c', penwidth: 2) if start_id
          last_step = @nodes.keys.last
          g.add_nodes(last_step.to_s, shape: 'doublecircle', color: '#aaaaaa', fillcolor: '#f5e7e7')

          @nodes.each_key do |node|
            next if node == start_id || node == last_step

            g.add_nodes(node.to_s, label: node.to_s.humanize.titleize)
          end

          @edges.each { |e| g.add_edges(e.from.to_s, e.to.to_s, style: 'bold', color: '#222222') }

          @conditional_edges.each do |ce|
            g.add_edges(ce.from.to_s, ce.then.to_s,
                        label: ce.label || 'Yes', color: '#00703c', fontcolor: '#00703c', penwidth: 2)
            g.add_edges(ce.from.to_s, ce.else.to_s,
                        label: 'Else', color: '#d4351c', fontcolor: '#d4351c', style: 'dashed')
          end

          @custom_branching_edges.each do |cbe|
            cbe.potential_transitions.each do |pt|
              Array(pt[:nodes]).each do |dest|
                g.add_edges(cbe.from.to_s, dest.to_s,
                            label: pt[:label], color: '#3366cc', style: 'dotted')
              end
            end
          end

          g
        end

        private

        # Returns a proc for a given conditional expression (symbol or proc).
        def build_predicate(raw)
          if raw.is_a?(Symbol) && @wizard.respond_to?(raw)
            proc { |data| @wizard.send(raw, data) }
          elsif raw.respond_to?(:call)
            raw
          else
            proc { |_data| false }
          end
        end
      end
    end
  end
end
