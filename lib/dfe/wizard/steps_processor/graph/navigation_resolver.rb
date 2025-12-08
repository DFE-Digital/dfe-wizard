module DfE
  module Wizard
    module StepsProcessor
      class Graph < Base
        # Evaluates edges and resolves next/previous steps.
        #
        # Contains all navigation logic:
        # - Evaluates predicates (symbols, procs)
        # - Determines next step based on edge type
        # - Calculates path traversal
        # - Handles callbacks
        #
        # @api private
        class NavigationResolver
          def initialize(registry:, wizard:)
            @registry = registry
            @wizard = wizard
            @predicate_caller = @wizard
          end

          # Navigate to next step.
          #
          # Evaluation order:
          # 1. Call before_next callbacks
          # 2. Check custom branching edges
          # 3. Check multiple conditional edges
          # 4. Check conditional edges
          # 5. Check simple edges
          # 6. Return nil if no match
          #
          # @param target_step [Symbol, nil]
          # @return [Symbol, nil]
          def next_step(target_step = nil)
            @registry.before_next_callbacks.each do |callback|
              result = callback.call
              return result unless result.nil?
            end

            next_step_without_callbacks(target_step)
          end

          # Navigate to previous step.
          #
          # Uses path_traversal to find the previous step in the path.
          #
          # @param target_step [Symbol, nil]
          # @return [Symbol, nil]
          def previous_step(target_step = nil)
            @registry.before_previous_callbacks.each do |callback|
              result = callback.call
              return result unless result.nil?
            end

            previous_step_without_callbacks(target_step)
          end

          # Calculate path from root to target step.
          #
          # Uses graph traversal (BFS) respecting all edge types.
          #
          # @param target_step [Symbol, nil]
          # @return [Array<Symbol>]
          def path_traversal(target_step = nil)
            target_step ||= @wizard.current_step_name
            current = compute_root_node
            steps = [current]
            depth_limit = @registry.nodes.size

            while current && current != target_step && steps.size < depth_limit
              next_node = next_step_without_callbacks(current)
              break if next_node.nil? || steps.include?(next_node)

              steps << next_node
              current = next_node
            end

            steps.include?(target_step) ? steps : []
          end

          private

          def compute_root_node
            return @registry.root_node if @registry.root_node

            if @registry.conditional_root_block
              @registry.conditional_root_block.call(@wizard.state_store)
            elsif @registry.conditional_root_method
              @predicate_caller.method(@registry.conditional_root_method).call
            end
          end

          def next_step_without_callbacks(target_step)
            target_step ||= @wizard.current_step_name
            next_candidate = evaluate_edges(target_step)

            return next_candidate unless next_candidate

            skip_until_showable(next_candidate)
          end

          def skip_until_showable(node_id)
            visited = Set.new

            while node_id
              return nil if visited.include?(node_id) # Cycle detection

              visited.add(node_id)

              return node_id unless skip_node?(node_id)

              node_id = evaluate_edges(node_id)
            end

            nil
          end

          def skip_node?(node_id)
            node = @registry.nodes[node_id]
            return false unless node&.skippable?

            call_predicate(node.skip_when)
          end

          def evaluate_edges(target_step)
            evaluate_custom_edge(target_step) ||
              evaluate_multiple_conditional_edge(target_step) ||
              evaluate_conditional_edge(target_step) ||
              evaluate_simple_edge(target_step)
          end

          def previous_step_without_callbacks(target_step = @wizard.current_step_name)
            root = compute_root_node
            return nil if target_step == root

            path = path_traversal(target_step)
            path[-2] if path.present?
          end

          def evaluate_custom_edge(target_step)
            edge = @registry.custom_branching_edges.find { |e| e.from == target_step }
            return unless edge

            result = call_predicate(edge.conditional)
            log_custom_edge(target_step, result)
            result
          end

          def evaluate_multiple_conditional_edge(target_step)
            edge = @registry.multiple_conditional_edges.find { |e| e.from == target_step }
            return unless edge

            matched_branch = find_matching_branch(edge, target_step)

            if matched_branch
              matched_branch[:then]
            else
              log_no_branch_matched(target_step, edge.default)
              edge.default
            end
          end

          def find_matching_branch(edge, target_step)
            edge.branches.find do |branch|
              result = call_predicate(branch[:when])
              if result
                log_branch_matched(target_step, branch, result)
                true
              end
            end
          end

          def evaluate_conditional_edge(target_step)
            edge = @registry.conditional_edges.find { |e| e.from == target_step }
            return unless edge

            result = call_predicate(edge.when)
            evaluated_step = result ? edge.then : edge.else
            log_conditional_edge(target_step, edge, result, evaluated_step)
            evaluated_step
          end

          def evaluate_simple_edge(target_step)
            edge = @registry.edges.find { |e| e.from == target_step }
            edge&.to
          end

          def call_predicate(predicate)
            if predicate.respond_to?(:call)
              predicate.call
            else
              @predicate_caller.method(predicate).call
            end
          end

          def log_custom_edge(target_step, result)
            return unless @wizard.log.respond_to?(:info)

            @wizard.log.info(
              "[Graph] Custom edge from :#{target_step} → #{result.inspect}",
              category: :step_processor,
            )
          end

          def log_branch_matched(target_step, branch, result)
            return unless @wizard.log.respond_to?(:info)

            @wizard.log.info(
              "[Graph] Branch from :#{target_step}: #{branch[:label]} (#{result}) → :#{branch[:then]}",
              category: :step_processor,
            )
          end

          def log_no_branch_matched(target_step, default_step)
            return unless @wizard.log.respond_to?(:info)

            @wizard.log.info(
              "[Graph] No branch matched from :#{target_step}, using default → :#{default_step}",
              category: :step_processor,
            )
          end

          def log_conditional_edge(target_step, edge, result, evaluated_step)
            return unless @wizard.log.respond_to?(:info)

            condition_str = result ? 'true' : 'false'
            message = "[Graph] Conditional from :#{target_step} " \
                      "(#{edge.label || 'condition'}) = #{condition_str} " \
                      "→ :#{evaluated_step}"

            @wizard.log.info(message, category: :step_processor)
          end
        end
      end
    end
  end
end
