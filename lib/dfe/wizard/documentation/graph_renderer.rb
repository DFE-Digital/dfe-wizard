module DfE
  module Wizard
    module Documentation
      # Renders a graph as GraphViz visualization
      #
      # Converts graph structure to visual representation using
      # a specified style theme.
      #
      # @api private
      class GraphRenderer
        def initialize(graph:, theme:, title:)
          @graph = graph
          @theme = theme
          @title = title
          @styles = Styles.for(theme)
        end

        # Render the graph as GraphViz
        #
        # @return [GraphViz]
        def render
          require 'ruby-graphviz'

          graphviz = GraphViz.new(
            @title,
            type: :digraph,
            **@styles.graph_config,
          )

          render_nodes(graphviz)
          render_edges(graphviz)

          graphviz
        end

        private

        # Render all nodes with styling
        #
        # @param graphviz [GraphViz]
        def render_nodes(graphviz)
          first = @graph.root_node
          last = @graph.nodes.keys.last

          @graph.nodes.each_key do |node_id|
            label = format_label(node_id)

            node_style = if node_id == first
                           @styles.first_step
                         elsif node_id == last
                           @styles.final_step
                         elsif outgoing_edge?(node_id)
                           @styles.regular_step
                         else
                           @styles.exit_step
                         end

            graphviz.add_nodes(node_id.to_s, label: label, **node_style)
          end
        end

        # Render all edges with styling
        #
        # @param graphviz [GraphViz]
        def render_edges(graphviz)
          render_simple_edges(graphviz)
          render_conditional_edges(graphviz)
          render_multiple_conditional_edges(graphviz)
          render_complex_edges(graphviz)
        end

        # Render simple sequential transitions
        #
        # @param graphviz [GraphViz]
        def render_simple_edges(graphviz)
          @graph.edges.each do |edge|
            graphviz.add_edges(
              edge.from.to_s,
              edge.to.to_s,
              **@styles.simple_transition,
            )
          end
        end

        # Render conditional if/else branching
        #
        # @param graphviz [GraphViz]
        def render_conditional_edges(graphviz)
          @graph.conditional_edges.each do |cond|
            yes_style = @styles.conditional_transition[:yes]
            no_style = @styles.conditional_transition[:no]

            graphviz.add_edges(
              cond.from.to_s, cond.then.to_s,
              label: cond.label || 'Yes',
              **yes_style
            )
            graphviz.add_edges(
              cond.from.to_s, cond.else.to_s,
              label: 'Else',
              **no_style
            )
          end
        end

        # Render multiple conditional branching (N-way)
        #
        # Shows each branch with its label and a dashed default edge if present.
        #
        # @param graphviz [GraphViz]
        def render_multiple_conditional_edges(graphviz)
          @graph.multiple_conditional_edges.each do |multi_edge|
            multi_edge.branches.each_with_index do |branch, index|
              branch_label = branch[:label] || "Branch #{index + 1}"

              graphviz.add_edges(
                multi_edge.from.to_s,
                branch[:then].to_s,
                label: branch_label,
                **@styles.multiple_conditional_transition,
              )
            end

            next unless multi_edge.default

            graphviz.add_edges(
              multi_edge.from.to_s,
              multi_edge.default.to_s,
              label: 'Default',
              **@styles.default_transition,
            )
          end
        end

        # Render complex multi-option branching
        #
        # @param graphviz [GraphViz]
        def render_complex_edges(graphviz)
          @graph.custom_branching_edges.each do |branch|
            branch.potential_transitions.each do |transition|
              Array(transition[:nodes]).each do |dest|
                graphviz.add_edges(
                  branch.from.to_s, dest.to_s,
                  label: transition[:label],
                  **@styles.complex_transition
                )
              end
            end
          end
        end

        # Check if a node has any outgoing edges
        #
        # @param node_id [Symbol]
        # @return [Boolean]
        def outgoing_edge?(node_id)
          @graph.edges.any? { |edge| edge.from == node_id } ||
            @graph.conditional_edges.any? { |cond_edge| cond_edge.from == node_id } ||
            @graph.custom_branching_edges.any? { |branch_edge| branch_edge.from == node_id } ||
            @graph.multiple_conditional_edges.any? { |multi_edge| multi_edge.from == node_id }
        end

        # Format node label for display
        #
        # @param node_id [Symbol]
        # @return [String]
        def format_label(node_id)
          node_id.to_s.humanize.titleize
        end
      end
    end
  end
end
