# frozen_string_literal: true

module DfE
  module Wizard
    module Documentation
      # GraphViz styling themes for wizard visualization
      #
      # Each style defines a complete visual language for graph rendering.
      # Three themes available:
      # - **:minimal** - Clean, simple representation (default)
      # - **:detailed** - Professional, information-rich
      # - **:semantic** - Color-coded by meaning (intuitive branching)
      #
      # @api private
      class Styles
        # Factory for creating style instances
        #
        # @param theme [Symbol]
        # @return [Styles]
        def self.for(theme)
          case theme
          when :detailed
            DetailedStyle.new
          when :semantic
            SemanticStyle.new
          else
            new # Minimal (default)
          end
        end

        # List all available themes
        #
        # @return [Array<Symbol>]
        def self.available_themes
          %i[minimal detailed semantic]
        end

        # Base graph configuration
        # @return [Hash]
        def graph_config
          {
            rankdir: 'LR',
            fontname: 'Arial',
            fontsize: 11,
          }
        end

        # Style for wizard entry point
        # @return [Hash]
        def first_step
          { color: '#00703c', fillcolor: '#d2f7ef', penwidth: 2 }
        end

        # Style for normal steps with outgoing transitions
        # @return [Hash]
        def regular_step
          { color: '#666666', fillcolor: '#f9f9f9', penwidth: 1 }
        end

        # Style for steps with no outgoing edges (dead-ends)
        # @return [Hash]
        def exit_step
          { color: '#666666', fillcolor: '#f9f9f9', penwidth: 1 }
        end

        # Style for multiple conditional edges (N-way branching)
        #
        # Used when rendering branches from add_multiple_conditional_edges.
        # Distinguishes N-way branching from binary conditionals with solid blue lines.
        #
        # @return [Hash] GraphViz edge attributes
        def multiple_conditional_transition
          {
            color: '#2563eb',
            fontcolor: '#2563eb',
            style: 'solid',
            penwidth: 1.5,
          }
        end

        # Style for default/fallback edges in multiple conditional branching
        #
        # Used when a multiple conditional edge has a default target.
        # Rendered as dashed gray lines to indicate fallback/catch-all behavior.
        #
        # @return [Hash] GraphViz edge attributes
        def default_transition
          {
            color: '#6b7280', # Gray for default path
            fontcolor: '#6b7280',
            style: 'dashed',
            penwidth: 1.5,
          }
        end

        # Style for wizard exit/final step
        # @return [Hash]
        def final_step
          { shape: 'doublecircle', color: '#aaaaaa', fillcolor: '#f5e7e7', penwidth: 1.5 }
        end

        # Style for simple sequential transitions
        # @return [Hash]
        def simple_transition
          { style: 'solid', color: '#222222', penwidth: 1 }
        end

        # Style for if/else conditional branches
        # Returns hash with :yes and :no keys for branch styling
        # @return [Hash]
        def conditional_transition
          {
            yes: { color: '#00703c', fontcolor: '#00703c', penwidth: 2, style: 'solid' },
            no: { color: '#d4351c', fontcolor: '#d4351c', penwidth: 1.5, style: 'dashed' },
          }
        end

        # Style for multi-option branching
        # @return [Hash]
        def complex_transition
          { color: '#3366cc', fontcolor: '#3366cc', style: 'dotted', penwidth: 1 }
        end
      end

      # Minimal style: Clean and simple
      # Best for quick reference and printing
      class MinimalStyle < Styles
        def graph_config
          super.merge(bgcolor: 'transparent')
        end

        def first_step
          { color: '#4CAF50', fillcolor: '#e8f5e9', penwidth: 2 }
        end

        def regular_step
          { color: '#cccccc', fillcolor: '#ffffff', penwidth: 1 }
        end

        def exit_step
          { color: '#cccccc', fillcolor: '#ffffff', penwidth: 1 }
        end

        def final_step
          { shape: 'doublecircle', color: '#4CAF50', fillcolor: '#e8f5e9', penwidth: 2 }
        end

        def simple_transition
          { color: '#cccccc', penwidth: 1 }
        end
      end

      # Detailed style: Professional and information-rich
      # Best for documentation and detailed analysis
      class DetailedStyle < Styles
        def graph_config
          super.merge(bgcolor: '#fafafa', margin: 0.5, ranksep: 1.0)
        end

        def first_step
          { shape: 'ellipse', color: '#1976d2', fillcolor: '#e3f2fd', penwidth: 2.5 }
        end

        def regular_step
          { color: '#546e7a', fillcolor: '#eceff1', penwidth: 1.5 }
        end

        def exit_step
          { color: '#546e7a', fillcolor: '#eceff1', penwidth: 1.5 }
        end

        def final_step
          { shape: 'ellipse', color: '#388e3c', fillcolor: '#e8f5e9', penwidth: 2.5 }
        end

        def simple_transition
          { style: 'bold', color: '#222222', penwidth: 1.5, arrowsize: 1.5 }
        end

        def conditional_transition
          {
            yes: { color: '#388e3c', fontcolor: '#388e3c', penwidth: 2.5, style: 'bold' },
            no: { color: '#d32f2f', fontcolor: '#d32f2f', penwidth: 2.5, style: 'dashed' },
          }
        end

        def complex_transition
          { color: '#7b1fa2', fontcolor: '#7b1fa2', style: 'dotted', penwidth: 1.5 }
        end
      end

      # Semantic style: Color-coded by meaning
      # Green = yes/flow, Red = no/exit, Blue = custom
      # Best for understanding branching logic
      class SemanticStyle < Styles
        def graph_config
          super.merge(bgcolor: '#ffffff', nodesep: 0.5, ranksep: 0.75)
        end

        def first_step
          { shape: 'ellipse', color: '#27ae60', fillcolor: '#d5f4e6', penwidth: 3 }
        end

        def regular_step
          { color: '#34495e', fillcolor: '#ecf0f1', penwidth: 1 }
        end

        def exit_step
          { color: '#34495e', fillcolor: '#ecf0f1', penwidth: 1 }
        end

        def final_step
          { shape: 'ellipse', color: '#c0392b', fillcolor: '#fadbd8', penwidth: 3 }
        end

        def simple_transition
          { style: 'solid', color: '#222222', penwidth: 2, arrowhead: 'vee' }
        end

        def conditional_transition
          {
            yes: { color: '#27ae60', fontcolor: '#27ae60', penwidth: 3, style: 'solid', arrowhead: 'vee' },
            no: { color: '#c0392b', fontcolor: '#c0392b', penwidth: 2, style: 'dashed', arrowhead: 'vee' },
          }
        end

        def complex_transition
          { color: '#2980b9', fontcolor: '#2980b9', style: 'dotted', penwidth: 2, arrowhead: 'open' }
        end
      end
    end
  end
end
