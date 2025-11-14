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
          raise ArgumentError, 'A block must be given to Graph.draw' unless block_given?

          graph = new(wizard)
          yield(graph) if block_given?
          raise ArgumentError, 'Graph must have a root node set. graph.root :some_step' unless graph.root_node

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

        def find_step(node_id)
          nodes[node_id]&.klass
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

        def before_next_step(method = nil, &block)
          @next_step_before_callbacks ||= []

          @next_step_before_callbacks << if block_given?
                                           block
                                         else
                                           @wizard.method(method)
                                         end
        end

        def before_previous_step(method = nil, &block)
          @previous_step_before_callbacks ||= []

          @previous_step_before_callbacks << if block_given?
                                               block
                                             else
                                               @wizard.method(method)
                                             end
        end

        def next_step(current_step = nil)
          if @next_step_before_callbacks&.any?
            @next_step_before_callbacks.each do |callback|
              result = callback.call
              return result unless result.nil?
            end
          end

          next_step_without_callbacks(current_step)
        end

        def next_step_without_callbacks(current_step = @wizard.current_step_name)
          custom_edge = @custom_branching_edges.find { |e| e.from == current_step }
          if custom_edge
            return call_predicate(custom_edge.conditional, current_step)
          end

          cond_edge = @conditional_edges.find { |e| e.from == current_step }
          if cond_edge
            result = call_predicate(cond_edge.when, current_step)
            return result ? cond_edge.then : cond_edge.else
          end

          edge = @edges.find { |e| e.from == current_step }

          edge&.to
        end

        def previous_step(current_step = nil)
          if @previous_step_before_callbacks&.any?
            @previous_step_before_callbacks.each do |callback|
              result = callback.call
              return result unless result.nil?
            end
          end

          previous_step_without_callbacks(current_step)
        end

        def previous_step_without_callbacks(current_step = @wizard.current_step_name)
          return nil if current_step == @root_node

          path = path_traversal(current_step)

          path[-2] if path.present?
        end

        # Returns a traversal path through the user's wizard so far.
        #
        def path_traversal(target_step = nil)
          target_step ||= @wizard.current_step_name

          current = @root_node

          steps = [current]

          depth_limit = @nodes.size

          while current && current != target_step && steps.size < depth_limit
            n = next_step_without_callbacks(current)

            break if n.nil? || steps.include?(n)

            steps << n

            current = n
          end

          steps.include?(target_step) ? steps : []
        end

        # Generate GraphViz visualization
        #
        # @param theme [Symbol] :minimal, :detailed, :semantic
        # @return [GraphViz]
        #
        # @example
        #   graph.to_doc(:semantic, title: 'Some Wizard').output(svg: 'wizard.svg')
        #
        def to_doc(title:, theme: :semantic)
          ::DfE::Wizard::Documentation::GraphRenderer.new(graph: self, theme:, title:).render
        end

        private

        def build_predicate(raw)
          if raw.is_a?(Symbol) && @wizard.respond_to?(raw)
            proc { |step, _wizard| @wizard.send(raw, step) }
          elsif raw.respond_to?(:call)
            raw
          else
            proc { |_step, _wizard| false }
          end
        end

        def call_predicate(predicate, current_step)
          arity = predicate.arity

          step_obj = @wizard.step(current_step)

          case arity
          when 2
            predicate.call(step_obj, @wizard)
          else
            predicate.call(step_obj)
          end
        end
      end
    end
  end
end
