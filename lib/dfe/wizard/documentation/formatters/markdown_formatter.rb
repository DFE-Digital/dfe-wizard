module DfE
  module Wizard
    module Documentation
      module Formatters
        class MarkdownFormatter
          def initialize(metadata, options = {})
            @metadata = metadata
            @options = options
            @generated_at = options.fetch(:generated_at) { Time.now.utc.iso8601 }
          end

          def render
            [
              render_header,
              render_overview,
              render_root_section,
              render_flow_diagram,
              render_steps_inventory,
              render_detailed_steps,
              render_transitions_overview,
              render_simple_transitions,
              render_conditional_transitions,
              render_multiple_conditional_transitions,
              render_custom_branching_transitions,
              render_statistics,
              render_example_journeys,
              render_raw_metadata,
            ].compact.join("\n\n")
          end

          private

          def render_header
            structure_type = @metadata[:structure_type] || :unknown

            <<~MD
              # Wizard Documentation

              **Structure Type:** `#{structure_type}`
              **Generated:** #{@generated_at}
              **Processor:** DfE::Wizard::StepsProcessor
            MD
          end

          def render_overview
            counts = @metadata[:counts] || {}
            steps_count = counts[:steps] || 0
            simple_transitions = counts[:simple_transitions] || 0
            cond_transitions = counts[:conditional_transitions] || 0
            multi_transitions = counts[:multiple_conditional_transitions] || 0
            custom_transitions = counts[:custom_branching_transitions] || 0
            total_transitions = simple_transitions + cond_transitions + multi_transitions + custom_transitions

            <<~MD
              ## Overview

              | Metric                           | Value                       |
              |----------------------------------|-----------------------------|
              | Total Steps                      | #{steps_count}              |
              | Simple Transitions               | #{simple_transitions}       |
              | Conditional Transitions          | #{cond_transitions}         |
              | Multiple Conditional Transitions | #{multi_transitions}        |
              | Custom Branching Transitions     | #{custom_transitions}       |
              | **Total Transitions**            | **#{total_transitions}**    |
            MD
          end

          def render_root_section
            root = @metadata[:root_step]
            return nil unless root

            if root.is_a?(Array)
              render_dynamic_root(root)
            else
              render_fixed_root(root)
            end
          end

          def render_fixed_root(root)
            <<~MD
              ## Root Entry Point (Fixed)

              **Entry Point:** `#{root}`

              All users start at this step. No conditional logic applies.
            MD
          end

          def render_dynamic_root(roots)
            roots_list = roots.map { |r| "- `#{r}`" }.join("\n")

            <<~MD
              ## Root Entry Points (Dynamic)

              This wizard uses conditional root logic. Users may enter at different steps based on runtime state evaluation.

              ### Possible Entry Points

              #{roots_list}

              **Determination:** Evaluated at initialization based on wizard state. See "Conditional Root Logic" section for details on which conditions route to which entry points.
            MD
          end

          def render_flow_diagram
            steps = @metadata[:steps] || {}
            return nil if steps.empty?

            ascii_diagram = generate_ascii_diagram(steps)

            <<~MD
              ## Wizard Flow

              ```
              #{ascii_diagram}
              ```

              ### Legend

              - **━━** Simple edge (linear progression, no condition)
              - **─┬─** Conditional edge (if/else decision point)
              - **┼** Multiple conditional edge (N-way branching)
              - **⊕** Custom branching edge (complex status-driven routing)
            MD
          end

          def generate_ascii_diagram(steps)
            transitions = @metadata[:transitions] || []
            root = @metadata[:root_step]

            # Build adjacency map
            graph = build_graph_structure(steps, transitions)

            # For simple case: just list steps vertically
            if transitions.empty? || transitions.all? { |t| t[:type] == :simple }
              render_linear_diagram(graph, root)
            else
              # For complex graphs: build proper ASCII diagram
              render_complex_diagram(graph, root, transitions)
            end
          end

          # Build graph structure for rendering
          def build_graph_structure(steps, transitions)
            graph = {}
            steps.each_key { |step_id| graph[step_id] = { children: [], type: :node } }

            transitions.each do |trans|
              from = trans[:from]
              case trans[:type]
              when :simple
                to = trans[:to]
                graph[from] ||= { children: [] }
                graph[from][:children] << { id: to, label: nil, type: :simple }
              when :conditional
                graph[from] ||= { children: [] }
                graph[from][:children] << { id: trans[:then], label: "#{trans[:label]} (✓)", type: :cond_true }
                graph[from][:children] << { id: trans[:else], label: "#{trans[:label]} (✗)", type: :cond_false }
              when :multiple_conditional
                graph[from] ||= { children: [] }
                trans[:branches]&.each do |branch|
                  graph[from][:children] << { id: branch[:then], label: branch[:label], type: :multi }
                end
              when :custom_branching
                graph[from] ||= { children: [] }
                trans[:potential_transitions]&.each do |pt|
                  pt[:nodes]&.each do |node|
                    graph[from][:children] << { id: node, label: pt[:label], type: :custom }
                  end
                end
              end
            end
            graph
          end

          # Simple linear diagram for sequential wizards
          def render_linear_diagram(graph, root)
            visited = Set.new
            output = []
            current = root
            current = Array(current).first if current.is_a?(Array)

            while current && !visited.include?(current)
              visited.add(current)
              output << "[:#{current}]"

              # Get next step
              next_steps = graph.dig(current, :children) || []
              current = next_steps.first&.dig(:id)
            end

            output.join("\n  ↓\n")
          end

          # Complex diagram with branching support
          def render_complex_diagram(graph, root, _transitions)
            roots = Array(root)
            output = []

            # Build visual representation
            roots.each do |entry_point|
              output << "[:#{entry_point}]"
              render_graph_subtree(graph, entry_point, output, '', Set.new)
            end

            output.compact.join("\n")
          end

          def render_graph_subtree(graph, node_id, output, indent, visited)
            return if visited.include?(node_id)

            visited.add(node_id)

            children = graph.dig(node_id, :children) || []
            return if children.empty?

            if children.length == 1
              child = children.first
              output << "#{indent}  ↓"
              output << "#{indent}[:#{child[:id]}]"
              render_graph_subtree(graph, child[:id], output, indent, visited)
            elsif children.length > 1
              children.each_with_index do |child, idx|
                is_last = idx == children.length - 1
                prefix = is_last ? '└─' : '├─'
                connector = is_last ? '  ' : '│ '
                label = child[:label] ? " #{child[:label]}" : ''

                output << "#{indent}#{prefix}→ [:#{child[:id]}]#{label}"
                render_graph_subtree(graph, child[:id], output, "#{indent}#{connector}", visited)
              end
            end
          end

          def render_steps_inventory
            steps = @metadata[:steps] || {}
            return nil if steps.empty?

            rows = steps.map do |id, data|
              "| `#{id}` | #{data[:label]} | `#{data[:class]}` |"
            end.join("\n")

            <<~MD
              ## Steps Inventory

              | Step ID | Label | Class |
              |---------|-------|-------|
              #{rows}
            MD
          end

          def render_detailed_steps
            steps = @metadata[:steps] || {}
            return nil if steps.empty?

            steps_sections = steps.map do |step_id, step_data|
              render_step_detail(step_id, step_data)
            end.join("\n\n")

            "## Detailed Step Specifications\n\n#{steps_sections}"
          end

          def render_step_detail(step_id, step_data)
            label = step_data[:label]
            klass = step_data[:class]

            entry = entry_step?(step_id)
            exit_steps = find_exit_destinations(step_id)
            exit_points = if exit_steps.empty?
                            '[Wizard End]'
                          else
                            exit_steps.map { |s| "`#{s}`" }.join(', ')
                          end

            section = <<~MD
              ### Step: `#{step_id}`

              **Label:** #{label}
              **Class:** `#{klass}`
              **Entry Point:** #{entry ? '✓ Yes' : '✗ No'}
              **Exit Points:** #{exit_points}

              #### Description

              Placeholder for step description. Add contextual information about
              this step's purpose, user interactions, and business logic.
            MD

            section += render_step_attributes(step_data) if @options.fetch(:step_attributes, true)
            section += render_step_validations(step_data) if @options.fetch(:step_validations, true)
            section += render_step_operations(step_data) if @options.fetch(:step_operations, true)

            section
          end

          def render_step_attributes(step_data)
            attributes = step_data[:attributes]
            return '' unless attributes&.any?

            rows = attributes.map do |attr|
              name = attr[:name] || attr['name'] || 'unknown'
              type = attr[:type] || attr['type'] || 'Unknown'
              required = attr[:required] || attr['required'] ? '✓' : '✗'
              description = attr[:description] || attr['description'] || ''

              "| `#{name}` | `#{type}` | #{required} | #{description} |"
            end.join("\n")

            <<~MD

              #### Attributes

              | Attribute | Type | Required | Description |
              |-----------|------|:--------:|-------------|
              #{rows}
            MD
          end

          def render_step_validations(step_data)
            validators = step_data[:validators]
            return '' unless validators&.any?

            validation_lines = validators.map do |validator|
              validator_name = validator[:name] || validator['name'] || 'Unknown'
              validator_type = validator[:type] || validator['type'] || 'custom'
              validator_message = validator[:message] || validator['message'] || ''

              "- **#{validator_name}** (`#{validator_type}`): #{validator_message}"
            end.join("\n")

            <<~MD

              #### Validations

              #{validation_lines}
            MD
          end

          def render_step_operations(step_data)
            operations = step_data[:operations]
            return '' unless operations&.any?

            rows = operations.map do |op|
              name = op[:name] || op['name'] || 'unknown'
              description = op[:description] || op['description'] || ''

              "| `#{name}` | #{description} |"
            end.join("\n")

            <<~MD

              #### Operations

              | Operation | Description |
              |-----------|-------------|
              #{rows}
            MD
          end

          def entry_step?(step_id)
            root = @metadata[:root_step]
            return false unless root

            if root.is_a?(Array)
              root.include?(step_id)
            else
              root == step_id
            end
          end

          def find_exit_destinations(step_id)
            transitions = @metadata[:transitions] || []
            destinations = Set.new

            transitions.each do |trans|
              next unless trans[:from] == step_id

              case trans[:type]
              when :simple
                destinations.add(trans[:to])
              when :conditional
                destinations.add(trans[:then])
                destinations.add(trans[:else])
              when :multiple_conditional
                trans[:branches]&.each { |b| destinations.add(b[:then]) }
                destinations.add(trans[:default])
              when :custom_branching
                trans[:potential_transitions]&.each do |pt|
                  pt[:nodes]&.each { |node| destinations.add(node) }
                end
              end
            end

            destinations.to_a.sort_by(&:to_s)
          end

          def render_transitions_overview
            transitions = @metadata[:transitions] || []
            return nil if transitions.empty?

            simple_count = transitions.count { |t| t[:type] == :simple }
            cond_count = transitions.count { |t| t[:type] == :conditional }
            multi_count = transitions.count { |t| t[:type] == :multiple_conditional }
            custom_count = transitions.count { |t| t[:type] == :custom_branching }

            <<~MD
              ## Transitions Reference

              This wizard contains **#{transitions.length} transitions** across 4 types:

              - **#{simple_count} simple transitions** – Linear progression (unconditional)
              - **#{cond_count} conditional transitions** – If/else branching logic
              - **#{multi_count} multiple conditional transitions** – N-way branching
              - **#{custom_count} custom branching transitions** – Complex status-driven routing
            MD
          end

          def render_simple_transitions
            transitions = @metadata[:transitions] || []
            simple = transitions.select { |t| t[:type] == :simple }
            return nil if simple.empty?

            rows = simple.map do |trans|
              from = trans[:from]
              to = trans[:to]
              "| `#{from}` | `#{to}` | Always proceeds (no condition) |"
            end.join("\n")

            <<~MD
              ### Simple Transitions

              Simple transitions allow linear, unconditional progression from one step to the next.

              | From | To | Behavior |
              |------|-----|----------|
              #{rows}
            MD
          end

          def render_conditional_transitions
            transitions = @metadata[:transitions] || []
            conditional = transitions.select { |t| t[:type] == :conditional }
            return nil if conditional.empty?

            sections = conditional.map do |trans|
              render_conditional_transition_detail(trans)
            end.join("\n\n")

            <<~MARKDOWN
              ### Conditional Transitions (If/Else)


              Conditional transitions split the flow into two branches based on a predicate evaluation.


              #{sections}"
            MARKDOWN
          end

          def render_conditional_transition_detail(trans)
            from = trans[:from]
            then_step = trans[:then]
            else_step = trans[:else]
            label = trans[:label] || 'Condition'

            <<~MD
              #### `#{from}` → `#{then_step}` OR `#{else_step}`

              | Property | Value |
              |----------|-------|
              | From | `#{from}` |
              | Condition | `#{label}` |
              | Then (if true) | `#{then_step}` |
              | Else (if false) | `#{else_step}` |

              **Flow Logic:**

              Evaluates the predicate `#{label}`:
              - If condition is **true** → proceed to `#{then_step}`
              - If condition is **false** → proceed to `#{else_step}`
            MD
          end

          def render_multiple_conditional_transitions
            transitions = @metadata[:transitions] || []
            multiple = transitions.select { |t| t[:type] == :multiple_conditional }
            return nil if multiple.empty?

            sections = multiple.map do |trans|
              render_multiple_conditional_detail(trans)
            end.join("\n\n")

            <<~MARKDOWN
              ### Multiple Conditional Transitions (N-way Branching)


              N-way transitions route to different steps based on multiple independent conditions.


              #{sections}"
            MARKDOWN
          end

          def render_multiple_conditional_detail(trans)
            from = trans[:from]
            label = trans[:label] || 'Classification'
            default = trans[:default]
            branches = trans[:branches] || []

            branch_rows = branches.map do |b|
              "| #{b[:label]} | `#{b[:then]}` |"
            end.join("\n")

            <<~MD
              #### `#{from}` → Multiple Destinations (#{branches.length} branches)

              | Property | Value |
              |----------|-------|
              | From | `#{from}` |
              | Label | #{label} |
              | Type | Multiple Conditional (N-way) |
              | Default | `#{default}` |

              **Branches:**

              | Branch | Destination |
              |--------|-------------|
              #{branch_rows}
              | (default, no match) | `#{default}` |
            MD
          end

          def render_custom_branching_transitions
            transitions = @metadata[:transitions] || []
            custom = transitions.select { |t| t[:type] == :custom_branching }
            return nil if custom.empty?

            sections = custom.map do |trans|
              render_custom_branching_detail(trans)
            end.join("\n\n")

            <<~MARKDOWN
              ### Custom Branching Transitions (Status-Driven)

              Custom branching uses a method to evaluate complex logic and route to multiple possible destinations.

              #{sections}
            MARKDOWN
          end

          def render_custom_branching_detail(trans)
            from = trans[:from]
            potential = trans[:potential_transitions] || []

            transition_rows = potential.map do |pt|
              destinations = pt[:nodes].map { |n| "`#{n}`" }.join(', ')
              "| #{pt[:label]} | #{destinations} |"
            end.join("\n")

            <<~MD
              #### `#{from}` → Multiple Destinations (Custom Logic)

              | Property | Value |
              |----------|-------|
              | From | `#{from}` |
              | Type | Custom Branching |

              **Potential Transitions:**

              | Condition | Destination(s) |
              |-----------|-----------------|
              #{transition_rows}
            MD
          end

          def render_statistics
            counts = @metadata[:counts] || {}
            total_steps = counts[:steps] || 0

            <<~MD
              ## Wizard Statistics

              | Metric | Count |
              |--------|-------|
              | Total Steps | #{total_steps} |
              | Simple Transitions | #{counts[:simple_transitions] || 0} |
              | Conditional Transitions | #{counts[:conditional_transitions] || 0} |
              | Multiple Conditional Transitions | #{counts[:multiple_conditional_transitions] || 0} |
              | Custom Branching Transitions | #{counts[:custom_branching_transitions] || 0} |
              | **Total Transitions** | **#{(counts.values - [counts[:steps]]).sum}** |
            MD
          end

          def render_example_journeys
            <<~MD
              ## Example User Journeys

              ### Journey 1: Typical Path

              ```
              1. [Entry]  Entry Step
              2. [Linear] Step A
              3. [Cond]   Step B or C (conditional)
              4. [N-way]  Step D (branching)
              5. [Exit]   Terminal Step
              ```

              ### Journey 2: Alternative Path

              ```
              1. [Entry]  Entry Step (alternate)
              2. [Linear] Step A
              3. [Status] Different terminal step based on status
              ```

              **Note:** Actual journeys depend on wizard state transitions and predicates.
            MD
          end

          def render_raw_metadata
            return nil unless @options.fetch(:include_raw_metadata, true)

            metadata_json = compact_json_format(@metadata)

            <<~MD
              ## Raw Metadata

              ```json
              #{metadata_json}
              ```

              **Note:** This is the unified metadata format consumed by all documentation formatters.
            MD
          end

          def compact_json_format(obj, indent = 0)
            case obj
            when Hash
              if obj.empty?
                '{}'
              else
                pairs = obj.map do |k, v|
                  key_json = k.inspect
                  val_json = compact_json_format(v, indent + 1)
                  "#{key_json}: #{val_json}"
                end.join(",\n#{'  ' * (indent + 1)}")

                "{\n#{'  ' * (indent + 1)}#{pairs}\n#{'  ' * indent}}"
              end
            when Array
              if obj.empty?
                '[]'
              else
                items = obj.map { |item| compact_json_format(item, indent + 1) }
                           .join(",\n#{'  ' * (indent + 1)}")
                "[\n#{'  ' * (indent + 1)}#{items}\n#{'  ' * indent}]"
              end
            when String
              obj.inspect
            else
              obj.to_json
            end
          end
        end
      end
    end
  end
end
