# lib/dfe/wizard/documentation/renderer.rb
# frozen_string_literal: true

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

          g = GraphViz.new(
            @title,
            type: :digraph,
            **@styles.graph_config,
          )

          render_nodes(g)
          render_edges(g)

          g
        end

        private

        # Render all nodes with styling
        #
        # @param g [GraphViz]
        def render_nodes(g)
          first = @graph.root_node
          last = @graph.nodes.keys.last

          @graph.nodes.each_key do |node_id|
            label = format_label(node_id)

            node_style = if node_id == first
                           @styles.first_step
                         elsif node_id == last
                           @styles.final_step
                         elsif has_outgoing_edge?(node_id)
                           @styles.regular_step
                         else
                           @styles.exit_step
                         end

            g.add_nodes(node_id.to_s, label: label, **node_style)
          end
        end

        # Render all edges with styling
        #
        # @param g [GraphViz]
        def render_edges(g)
          render_simple_edges(g)
          render_conditional_edges(g)
          render_complex_edges(g)
        end

        # Render simple sequential transitions
        #
        # @param g [GraphViz]
        def render_simple_edges(g)
          @graph.edges.each do |edge|
            g.add_edges(
              edge.from.to_s,
              edge.to.to_s,
              **@styles.simple_transition,
            )
          end
        end

        # Render conditional if/else branching
        #
        # @param g [GraphViz]
        def render_conditional_edges(g)
          @graph.conditional_edges.each do |cond|
            yes_style = @styles.conditional_transition[:yes]
            no_style = @styles.conditional_transition[:no]

            g.add_edges(
              cond.from.to_s, cond.then.to_s,
              label: cond.label || 'Yes',
              **yes_style
            )
            g.add_edges(
              cond.from.to_s, cond.else.to_s,
              label: 'Else',
              **no_style
            )
          end
        end

        # Render complex multi-option branching
        #
        # @param g [GraphViz]
        def render_complex_edges(g)
          @graph.custom_branching_edges.each do |branch|
            branch.potential_transitions.each do |transition|
              Array(transition[:nodes]).each do |dest|
                g.add_edges(
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
        def has_outgoing_edge?(node_id)
          @graph.edges.any? { |e| e.from == node_id } ||
            @graph.conditional_edges.any? { |ce| ce.from == node_id } ||
            @graph.custom_branching_edges.any? { |cbe| cbe.from == node_id }
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
