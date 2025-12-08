module DfE
  module Wizard
    module Documentation
      module Formatters
        # Mermaid flowchart formatter for wizard visualization.
        #
        # Generates interactive Mermaid diagram syntax from wizard metadata.
        # Output is suitable for embedding in Markdown docs or rendering with Mermaid CLI.
        #
        # @example Generate Mermaid diagram
        #   formatter = MermaidFormatter.new(metadata_hash, options)
        #   content = formatter.render
        #   # => "flowchart TD\n  step1[Step One]\n  step1 --> step2[Step Two]\n..."
        #
        # @example Embed in Markdown
        #   markdown = %{
        #     # Wizard Documentation
        #     ```
        #     #{content}
        #     ```
        #   }
        #
        # @api public
        # @since 3.0.0
        class MermaidFormatter
          # Initialize Mermaid formatter
          #
          # @param metadata [Hash] Wizard metadata from Core::Metadata#to_h
          # @param options [Hash] Configuration options
          # @option options [Time] :generated_at (Time.now.utc) When diagram was generated
          #
          # @example
          #   formatter = MermaidFormatter.new(metadata, generated_at: Time.current)
          def initialize(metadata, options = {})
            @metadata = metadata
            @options = options
            @generated_at = options.fetch(:generated_at) { Time.now.utc }.iso8601
          end

          # Render Mermaid flowchart diagram
          #
          # Generates a complete Mermaid diagram from wizard metadata including:
          # - Node definitions (steps)
          # - Edge definitions (transitions with labels)
          # - Flow direction (top-down by default)
          #
          # @return [String] Mermaid diagram syntax (valid for rendering/export)
          #
          # @example
          #   content = formatter.render
          #   File.write('wizard.mmd', content)
          def render
            [
              render_header,
              render_steps,
              render_transitions,
              render_styles,
            ].compact.join("\n")
          end

          def render_styles
            skippable_steps = @metadata[:steps].select { |_, data| data[:skippable?] }.keys
            return '' if skippable_steps.empty?

            skippable_steps.map do |skippable_step|
              "  style #{skippable_step} stroke:#FFA500,stroke-dasharray: 5 5,stroke-width:2px"
            end.join("\n")
          end

          private

          def render_header
            'flowchart TD'
          end

          def render_steps
            steps = @metadata[:steps] || {}
            return '' if steps.empty?

            steps.map do |step_id, step_data|
              label = step_data[:label] || step_id.to_s.titleize

              if step_data[:skippable?] && step_data[:skip_when]
                condition_name = step_data[:skip_when].to_s.sub('?', '').titleize

                skippable_text = %(⊘ Skippable when: #{condition_name})
              end

              sanitized_label = sanitize_label(label)

              if skippable_text.present?
                "  #{step_id}[\"#{sanitized_label}\n#{skippable_text}\"]"
              else
                "  #{step_id}[\"#{sanitized_label}\"]"
              end
            end.join("\n")
          end

          def render_transitions
            transitions = @metadata[:transitions] || []
            return '' if transitions.empty?

            transitions.map do |trans|
              case trans[:type]
              when :simple
                render_simple_transition(trans)
              when :conditional
                render_conditional_transition(trans)
              when :multiple_conditional
                render_multiple_conditional_transition(trans)
              when :custom_branching
                render_custom_branching_transition(trans)
              end
            end.compact.join("\n")
          end

          def render_simple_transition(transition)
            from = transition[:from]
            to = transition[:to]
            "  #{from} --> #{to}"
          end

          def render_conditional_transition(transition)
            from = transition[:from]
            then_step = transition[:then]
            else_step = transition[:else]
            label = transition[:label] || transition[:when] || 'condition'

            [
              "  #{from} -->|#{label}: ✓ yes| #{then_step}",
              "  #{from} -->|#{label}: ✗ no| #{else_step}",
            ].join("\n")
          end

          def render_multiple_conditional_transition(transition)
            from = transition[:from]
            branches = transition[:branches] || []
            default_step = transition[:default]

            lines = branches.map do |branch|
              label = branch[:label] || branch[:when] || 'branch'
              to = branch[:then]
              "  #{from} -->|#{label}: ✓ yes| #{to}"
            end

            if default_step
              lines << "  #{from} -->|else| #{default_step}"
            end

            lines.join("\n")
          end

          def render_custom_branching_transition(transition)
            from = transition[:from]
            potential = transition[:potential_transitions] || []

            potential.map do |pt|
              label = pt[:label] || 'status'
              nodes = pt[:nodes] || []
              nodes.map { |node| "  #{from} -->|#{label}| #{node}" }
            end.flatten.join("\n")
          end

          def sanitize_label(label)
            label.to_s
                 .gsub('"', '\\"')
                 .gsub('|', '\\|')
                 .gsub('<', '&lt;')
                 .gsub('>', '&gt;')
          end
        end
      end
    end
  end
end
