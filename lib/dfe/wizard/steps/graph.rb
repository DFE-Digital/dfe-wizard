module DfE
  module Wizard
    module Steps
      class Graph
        Node = Struct.new(:id, :klass, keyword_init: true)
        attr_reader :wizard, :nodes, :edges, :branches, :start_node

        def self.draw(wizard)
          graph = new(wizard)
          yield(graph) if block_given?
          graph
        end

        def initialize(wizard)
          @wizard = wizard
          @nodes = {}
          @edges = {}
          @branches = {}
          @start_node = nil

          wizard.steps_mapping.each do |step_hash|
            step_hash.each do |id, klass|
              @nodes[id] = Node.new(id:, klass:)
            end
          end
        end

        def start(node_id)
          @start_node = node_id
        end

        def add_edge(from, to:)
          @edges[from] ||= []
          @edges[from] << { to: }
        end

        def add_branch(from, when:, then:, else:, label: nil)
          @branches[from] ||= []
          @branches[from] << {
            when:,
            then:,
            else:,
            label:
          }
        end

        # Determine next step based on current step and data
        def next_step(step = nil, data = nil)
          step ||= wizard.current_step_name
          data ||= wizard.data

          # Check if there are conditional branches for this step
          if @branches[step]
            branch = @branches[step].first

            # Evaluate the condition
            condition_result = evaluate_condition(branch[:when], data)

            # Return the appropriate next step based on condition
            return condition_result ? branch[:then] : branch[:else]
          end

          # If no branches, check for direct edges
          if @edges[step] && !@edges[step].empty?
            return @edges[step].first[:to]
          end

          # No next step found
          nil
        end

        # Determine previous step based on current step and data
        def previous_step(step = nil, data = nil)
          step ||= wizard.current_step_name
          data ||= wizard.data

          # Special case: if we're at the start node, there's no previous step
          return nil if step == @start_node

          # Get visited steps up to the current step
          steps = path_traversal(step, data)

          # If current step not found in visited steps or it's the first step
          return nil if steps.empty? || steps.length < 2

          # Return the step before the current one
          steps[-2]
        end

        # Get all steps visited from start to target step
        def path_traversal(target_step = nil, data = nil)
          target_step ||= wizard.current_step_name
          data ||= wizard.data

          return [] unless @start_node

          # Use the number of nodes as the max depth limit
          max_depth = @nodes.size

          # Start with just the start node
          path = [@start_node]
          visited = Set.new

          # Continue until we reach the target or run out of steps
          current = @start_node

          while current != target_step
            # If we've exceeded the maximum possible depth, return empty path
            return [] if path.length >= max_depth

            visited.add(current)
            next_step_value = next_step(current, data)

            # If no next step or we'd create a cycle, return empty path
            if next_step_value.nil? || visited.include?(next_step_value)
              return []
            end

            # Add the next step to our path
            path << next_step_value
            current = next_step_value
          end

          path
        end

        private

        def evaluate_condition(condition, data)
          if condition.is_a?(Symbol) && wizard.respond_to?(condition)
            # Call the method on the wizard with data
            wizard.send(condition, data)
          elsif condition.respond_to?(:call)
            # Call the lambda/proc with data
            condition.call(data)
          else
            false
          end
        end
      end
    end
  end
end
