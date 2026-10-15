module DfE
  module Wizard
    module Documentation
      module Formatters
        # Graphviz DOT format formatter for wizard visualization.
        #
        # Generates Graphviz directed graph syntax from wizard metadata.
        # Output is suitable for exporting to PDF, PNG, SVG via Graphviz CLI.
        #
        # @example Generate Graphviz diagram
        #   formatter = GraphvizFormatter.new(metadata_hash, options)
        #   content = formatter.render
        #   # => "digraph Wizard {\n  rankdir=LR;\n  step1 [label=\"Step One\"];\n..."
        #
        # @example Export to PDF
        #   content = formatter.render
        #   File.write('wizard.dot', content)
        #   `dot -Tpdf wizard.dot -o wizard.pdf`
        #
        # @api public
        # @since 3.0.0
        class GraphvizFormatter
          # Initialize Graphviz formatter
          #
          # @param metadata [Hash] Wizard metadata from Core::Metadata#to_h
          # @param options [Hash] Configuration options
          # @option options [Time] :generated_at (Time.now.utc) When diagram was generated
          # @option options [String] :rankdir ('LR') Graph direction (LR=left-to-right, TD=top-down)
          # @option options [String] :bgcolor ('#ffffff') Background color (hex or named)
          #
          # @example
          #   formatter = GraphvizFormatter.new(metadata, rankdir: 'TD', bgcolor: '#f0f0f0')
          def initialize(metadata, options = {})
            @metadata = metadata
            @options = options
            @generated_at = options.fetch(:generated_at) { Time.now.utc.iso8601 }
            @rankdir = options.fetch(:rankdir, 'LR')
            @bgcolor = options.fetch(:bgcolor, '#ffffff')
          end

          # Render Graphviz DOT format diagram
          #
          # Generates a complete directed graph from wizard metadata including:
          # - Graph attributes (direction, styling)
          # - Node definitions with styling
          # - Edge definitions with labels and styles
          #
          # @return [String] Graphviz DOT format syntax (valid for dot command)
          #
          # @example
          #   content = formatter.render
          #   File.write('wizard.dot', content)
          def render
            [
              render_digraph_start,
              render_graph_attributes,
              render_steps,
              render_sub_wizards,
              render_transitions,
              render_change_journeys,
              render_digraph_end,
            ].compact.join("\n")
          end

          private

          def render_digraph_start
            wizard_name = sanitize_identifier(@metadata[:wizard_name].to_s)
            "digraph #{wizard_name} {"
          end

          def render_graph_attributes
            attributes = [
              "  rankdir=#{@rankdir};",
              "  bgcolor=\"#{@bgcolor}\";",
              '  node [shape=box, style="rounded,filled", fillcolor="#e8f4f8", fontname="Helvetica"];',
              '  edge [fontname="Helvetica", fontsize=10];',
            ]
            # Lets a depends_on edge end at a sub-wizard's cluster
            attributes << '  compound=true;' if sub_wizards.any?
            attributes.join("\n")
          end

          def render_steps
            steps = @metadata[:steps] || {}
            return '' if steps.empty?

            steps.except(*sub_wizard_step_ids).map do |step_id, step_data|
              render_step(step_id, step_data)
            end.join("\n")
          end

          def render_step(step_id, step_data, indent: '  ')
            label = step_data[:label] || step_id.to_s.titleize
            sanitized_id = sanitize_identifier(step_id.to_s)
            sanitized_label = sanitize_label(label)
            "#{indent}#{sanitized_id} [label=\"#{sanitized_label}\"];"
          end

          # Each sub-wizard as a cluster that holds its steps
          def render_sub_wizards
            return nil if sub_wizards.empty?

            steps = @metadata[:steps] || {}
            sub_wizards.map do |unit_id, unit_data|
              lines = [
                "  subgraph cluster_#{sanitize_identifier(unit_id.to_s)} {",
                "    label=\"#{sanitize_label(unit_id.to_s.titleize)}\";",
                '    style=dashed;',
              ]
              lines += unit_data[:steps].map { |step_id| render_step(step_id, steps[step_id] || {}, indent: '    ') }
              lines << '  }'
              lines.join("\n")
            end.join("\n")
          end

          # A dashed edge from the step that owns each depends_on answer to
          # each unit that depends on it. An edge to a sub-wizard ends at its
          # cluster.
          def render_change_journeys
            journeys = @metadata[:change_journeys] || {}
            return nil if journeys.empty?

            journeys.flat_map do |name, journey|
              from = sanitize_identifier(journey[:from].to_s)
              journey[:units].map do |unit_id|
                sub_wizard = sub_wizards[unit_id]
                if sub_wizard
                  to = sanitize_identifier(sub_wizard[:steps].first.to_s)
                  lhead = ", lhead=cluster_#{sanitize_identifier(unit_id.to_s)}"
                else
                  to = sanitize_identifier(unit_id.to_s)
                end
                "  #{from} -> #{to} [label=\"#{sanitize_label(name)}\", style=dashed, color=gray#{lhead}];"
              end
            end.join("\n")
          end

          def sub_wizards
            @metadata[:sub_wizards] || {}
          end

          def sub_wizard_step_ids
            sub_wizards.values.flat_map { |unit_data| unit_data[:steps] }
          end

          def render_transitions
            transitions = @metadata[:transitions] || []
            return '' if transitions.empty?

            transitions.map do |trans|
              case trans[:type]
              when :simple
                render_simple_edge(trans)
              when :conditional
                render_conditional_edges(trans)
              when :multiple_conditional
                render_multiple_edges(trans)
              when :custom_branching
                render_custom_edges(trans)
              end
            end.compact.join("\n")
          end

          def render_simple_edge(transition)
            from = sanitize_identifier(transition[:from].to_s)
            to = sanitize_identifier(transition[:to].to_s)
            "  #{from} -> #{to} [style=solid];"
          end

          def render_conditional_edges(transition)
            from = sanitize_identifier(transition[:from].to_s)
            then_step = sanitize_identifier(transition[:then].to_s)
            else_step = sanitize_identifier(transition[:else].to_s)
            label = transition[:label] || 'condition'

            [
              "  #{from} -> #{then_step} [label=\"#{label}\\nyes\", style=dashed, color=blue];",
              "  #{from} -> #{else_step} [label=\"#{label}\\nno\", style=dashed, color=blue];",
            ].join("\n")
          end

          def render_multiple_edges(transition)
            from = sanitize_identifier(transition[:from].to_s)
            branches = transition[:branches] || []

            branches.map do |branch|
              label = branch[:label] || 'branch'
              to = sanitize_identifier(branch[:then].to_s)
              "  #{from} -> #{to} [label=\"#{label}\", style=dotted, color=green];"
            end.join("\n")
          end

          def render_custom_edges(transition)
            from = sanitize_identifier(transition[:from].to_s)
            potential = transition[:potential_transitions] || []

            potential.map do |pt|
              label = pt[:label] || 'status'
              nodes = pt[:nodes] || []
              nodes.map do |node|
                to = sanitize_identifier(node.to_s)
                "  #{from} -> #{to} [label=\"#{label}\", style=bold, color=red];"
              end
            end.flatten.join("\n")
          end

          def render_digraph_end
            '}'
          end

          def sanitize_identifier(identifier)
            identifier.gsub(/[^a-zA-Z0-9_]/, '_')
          end

          def sanitize_label(label)
            label.to_s
                 .gsub('\\', '\\\\')
                 .gsub('"', '\\"')
                 .gsub("\n", '\\n')
          end
        end
      end
    end
  end
end
