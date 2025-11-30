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
        ConditionalEdge = Struct.new(:from, :when, :then, :else, :label, :original_when, keyword_init: true)
        CustomBranchingEdge = Struct.new(:from, :conditional, :potential_transitions, keyword_init: true)
        MultipleConditionalEdge = Struct.new(:from, :branches, :default, :label, keyword_init: true)

        attr_reader :nodes,
                    :edges,
                    :conditional_edges,
                    :custom_branching_edges,
                    :multiple_conditional_edges

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
          @multiple_conditional_edges = []
          @root_node = nil
          @conditional_root = nil
        end

        # Adds a step node to the graph.
        # @param node_id [Symbol]
        # @param klass [Class]
        def add_node(node_id, klass)
          @nodes[node_id] = Node.new(id: node_id, klass: klass)
        end

        def conditional_root(method_name = nil, &block)
          if @root_node.present? || @conditional_root_block.present? || @conditional_root_method.present?
            raise ArgumentError,
                  'Cannot set both root and conditional_root. Use one or the other.'
          end

          if method_name.present? && block_given?
            raise ArgumentError,
                  'Provide either a method name (symbol) or a block, not both'
          end

          unless method_name.present? || block_given?
            raise ArgumentError,
                  'conditional_root requires a block or method name'
          end

          if method_name.present?
            unless @wizard.respond_to?(method_name, include_private: true)
              raise ArgumentError,
                    "method :#{method_name} not found on wizard #{@wizard.class.name}. " \
                    'Create the method or use a block instead.'
            end
            @conditional_root_method = method_name
          end

          if block_given?
            @conditional_root_block = block
          end
        end

        def root_node
          return @root_node if @root_node.present?
          return @conditional_root_block.call(@wizard.state_store) if @conditional_root_block.present?

          @wizard.method(@conditional_root_method).call if @conditional_root_method.present?
        end

        def step_definitions
          @nodes.values
        end

        # Finds the step class for a given node
        #
        # Returns the class associated with a node identifier.
        # Used internally by the wizard to instantiate step objects.
        #
        # @param node_id [Symbol] The node identifier
        # @return [Class, nil] The step class, or nil if node doesn't exist
        #
        # @example
        #   graph.find_step(:name) # => Steps::Name
        #   graph.find_step(:missing) # => nil
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
            original_when: options[:when],
          )
        end

        # Adds multiple conditional branches from a single node (N-way branching).
        #
        # Branches are evaluated in order; the first matching condition wins.
        # If no conditions match, routes to the `default` node (if specified).
        #
        # Use this when you have 2+ mutually exclusive conditions from one step.
        # For binary decisions (yes/no), use `add_conditional_edge` instead.
        #
        # @param from [Symbol] The source node identifier
        # @param branches [Array<Hash>] Ordered array of condition-target pairs. Each hash must contain:
        #   - `:when` [Symbol, Proc] Predicate to evaluate (should return truthy/falsy)
        #   - `:then` [Symbol] Target node identifier if condition matches
        #   - `:label` [String] (optional) Human-readable description for graph visualization
        # @param default [Symbol, nil] Fallback target node when no branch conditions match
        # @param label [String, nil] Overall description of this branching point for documentation
        #
        # @raise [ArgumentError] if branches array is empty
        # @raise [ArgumentError] if any branch is missing required :when or :then keys
        # @raise [ArgumentError] if :from node doesn't exist in the graph
        #
        # @note Branches are evaluated **in the order specified**. Order matters when conditions overlap.
        # @note Always place more specific conditions before more general ones to avoid unreachable branches.
        # @note Avoid unconditional branches in the middle of the array (they make subsequent branches unreachable).
        #
        # @example Visa type routing
        #   graph.add_many_conditional_edges(
        #     from: :visa_selection,
        #     branches: [
        #       { when: :student_visa?, then: :student_details },
        #       { when: :work_visa?, then: :work_details },
        #       { when: :family_visa?, then: :family_details }
        #     ],
        #     default: :other_visa
        #   )
        #
        # @example Age-based routing with overlapping conditions (specific first)
        #   graph.add_many_conditional_edges(
        #     from: :age_check,
        #     branches: [
        #       { when: ->(step) { step.age < 18 }, then: :minor_path },
        #       { when: ->(step) { step.age >= 65 }, then: :senior_path },
        #       { when: ->(step) { step.age >= 18 }, then: :adult_path }
        #     ]
        #   )
        #
        # @example With safety check first
        #   graph.add_many_conditional_edges(
        #     from: :payment,
        #     branches: [
        #       { when: :payment_failed?, then: :error_page },
        #       { when: :full_payment?, then: :receipt },
        #       { when: :partial_payment?, then: :payment_plan }
        #     ],
        #     default: :manual_review
        #   )
        #
        def add_multiple_conditional_edges(from:, branches:, default: nil, label: nil)
          unless @nodes.key?(from)
            raise ArgumentError,
                  "Cannot add branches from non-existent node :#{from}. " \
                  "Available nodes: #{@nodes.keys.inspect}. " \
                  "Did you forget to call add_node(:#{from}, StepClass)?"
          end

          if branches.nil? || branches.empty?
            raise ArgumentError,
                  "branches array cannot be empty for add_multiple_conditional_edges from :#{from}. " \
                  'Provide at least one branch with :when and :then keys, or use add_edge for unconditional routing.'
          end

          processed_branches = branches.map.each_with_index do |branch, index|
            unless branch.is_a?(Hash)
              raise ArgumentError,
                    "Branch at index #{index} must be a Hash, got #{branch.class}. " \
                    'Expected format: { when: :predicate, then: :target_node }'
            end

            unless branch.key?(:when)
              raise ArgumentError,
                    "Branch at index #{index} from :#{from} is missing required key :when. " \
                    "Expected format: { when: :predicate, then: :target_node, label: 'optional for doc' }"
            end

            unless branch.key?(:then)
              raise ArgumentError,
                    "Branch at index #{index} from :#{from} is missing required key :then. " \
                    "Expected format: { when: :predicate, then: :target_node, label: 'optional for doc' }"
            end

            unless @nodes.key?(branch[:then])
              raise ArgumentError,
                    "Branch #{index} from :#{from} points to non-existent node :#{branch[:then]}. " \
                    "Available nodes: #{@nodes.keys.inspect}. This may cause wizard navigation bugs."
            end

            {
              original_when: branch[:when],
              when: build_predicate(branch[:when]),
              then: branch[:then],
              label: branch[:label],
            }
          end

          @multiple_conditional_edges << MultipleConditionalEdge.new(
            from: from,
            branches: processed_branches,
            default: default,
            label: label,
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
          evaluate_custom_edge(current_step) ||
            evaluate_multiple_conditional_edge(current_step) ||
            evaluate_conditional_edge(current_step) ||
            evaluate_simple_edge(current_step)
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
          current = root_node

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
          if raw.is_a?(Symbol) && !@wizard.respond_to?(raw)
            raise ArgumentError,
                  "Predicate method :#{raw} not found on wizard #{@wizard.class.name}. " \
                  'Did you forget to create the method? Alternatively, you can delegate it to state_store.'
          end

          if raw.is_a?(Symbol) && @wizard.respond_to?(raw)
            predicate_method = @wizard.method(raw)

            case predicate_method.arity
            when ->(arity) { arity.zero? || arity.negative? }
              proc { predicate_method.call }
            else
              proc { |step| predicate_method.call(step) }
            end

          elsif raw.respond_to?(:call)
            raw
          else
            raise ArgumentError,
                  "Predicate must be a Symbol (method name) or callable (responds to #call). Got: #{raw.class}"
          end
        end

        def evaluate_custom_edge(current_step)
          custom_edge = @custom_branching_edges.find { |e| e.from == current_step }
          return unless custom_edge

          result = call_predicate(custom_edge.conditional, current_step)
          log_custom_edge(current_step, result)
          result
        end

        def evaluate_multiple_conditional_edge(current_step)
          multiple_edge = @multiple_conditional_edges.find { |e| e.from == current_step }
          return unless multiple_edge

          matched_branch = find_matching_branch(multiple_edge, current_step)

          if matched_branch
            matched_branch[:then]
          else
            log_no_branch_matched(current_step, multiple_edge.default)
            multiple_edge.default
          end
        end

        def find_matching_branch(multiple_edge, current_step)
          multiple_edge.branches.find do |branch|
            result = call_predicate(branch[:when], current_step)
            if result
              log_branch_matched(current_step, branch, result)
              true
            end
          end
        end

        def evaluate_conditional_edge(current_step)
          conditional_edge = @conditional_edges.find { |e| e.from == current_step }
          return unless conditional_edge

          result = call_predicate(conditional_edge.when, current_step)
          evaluated_step = result ? conditional_edge.then : conditional_edge.else
          log_conditional_edge(current_step, conditional_edge, result, evaluated_step)
          evaluated_step
        end

        def evaluate_simple_edge(current_step)
          edge = @edges.find { |e| e.from == current_step }
          edge&.to
        end

        def log_custom_edge(current_step, result)
          return unless @wizard.log.respond_to?(:info)

          @wizard.log.info(
            "[Graph] Custom edge evaluated from step :#{current_step} → #{result.inspect}",
            category: log_category,
          )
        end

        def log_branch_matched(current_step, branch, result)
          return unless @wizard.log.respond_to?(:info)

          @wizard.log.info(
            "[Graph] Branch evaluated from step :#{current_step}: " \
            "#{branch[:original_when]}=#{result.inspect} → :#{branch[:then]}",
            category: log_category,
          )
        end

        def log_no_branch_matched(current_step, default_step)
          return unless @wizard.log.respond_to?(:info)

          @wizard.log.info(
            "[Graph] No branch matched from step :#{current_step}, " \
            "using default option → :#{default_step}",
            category: log_category,
          )
        end

        def log_conditional_edge(current_step, edge, result, evaluated_step)
          return unless @wizard.log.respond_to?(:info)

          @wizard.log.info(
            "[Graph] Conditional edge evaluated from step :#{current_step}: " \
            "#{edge.original_when}=#{result.inspect} → :#{evaluated_step}",
            category: log_category,
          )
        end

        def log_category
          :step_processor
        end

        def call_predicate(predicate, current_step)
          arity = predicate.arity
          step_object = @wizard.step(current_step)

          if arity == 2
            predicate.call(step_object, @wizard)
          else
            predicate.call(step_object)
          end
        end
      end
    end
  end
end
