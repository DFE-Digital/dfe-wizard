require_relative 'graph/dsl'
require_relative 'graph/registry'
require_relative 'graph/navigation_resolver'

module DfE
  module Wizard
    module StepsProcessor
      # Graph-based steps processor for multi-step wizards.
      #
      # Supports linear, conditional, and custom branching with explicit
      # node/edge definitions. Separates concerns into three focused classes:
      #
      # 1. **Graph** - Public interface (root_step, next_step, previous_step,
      #                path_traversal, find_step, step_definitions, metadata)
      # 2. **Registry** - Data storage (nodes, edges, callbacks)
      # 3. **NavigationResolver** - Navigation logic (predicate evaluation, edge traversal)
      #
      # Use Graph for multi-path workflows where step order isn't linear.
      #
      # @example Simple linear graph
      #   Graph.draw(wizard) do |g|
      #     g.add_node :step1, Step1
      #     g.add_node :step2, Step2
      #     g.root :step1
      #     g.add_edge from: :step1, to: :step2
      #   end
      #
      # @example With conditional branching
      #   Graph.draw(wizard) do |g|
      #     g.add_node :visa_type, VisaTypeStep
      #     g.add_node :student, StudentDetailsStep
      #     g.add_node :work, WorkDetailsStep
      #
      #     g.root :visa_type
      #     g.add_conditional_edge from: :visa_type, when: :student_visa?, then: :student, else: :work
      #   end
      class Graph < Base
        # Builds a wizard graph, yielding the DSL so the caller can add nodes/edges.
        #
        # @param wizard [Object] The wizard instance (for method predicates)
        # @yieldparam dsl [DSL] The graph DSL builder
        # @return [Graph]
        #
        # @raise [ArgumentError] If no block given
        # @raise [ArgumentError] If root node not set
        #
        # @example
        #   Graph.draw(wizard) do |g|
        #     g.add_node :step1, Step1
        #     g.root :step1
        #   end
        def self.draw(wizard)
          raise ArgumentError, 'A block must be given to Graph.draw' unless block_given?

          graph = new(wizard)
          dsl = DSL.new(graph.registry, wizard)
          yield(dsl)

          unless graph.root_step
            raise ArgumentError, 'Graph must have a root node set. Call g.root(:some_step)'
          end

          graph
        end

        attr_reader :registry, :resolver

        # @param wizard [Object] The wizard instance
        # @api public
        def initialize(wizard)
          @wizard = wizard
          @registry = Registry.new
          @resolver = NavigationResolver.new(registry: @registry, wizard:)
        end

        # Return the root (starting) step for this graph.
        #
        # Root can be:
        # - **Fixed**: Set once at build time with `g.root(:step_id)`
        # - **Dynamic**: Evaluated at runtime with `g.conditional_root { |state| ... }`
        #
        # @return [Symbol] Root step ID
        # @raise [ArgumentError] If no root defined
        #
        # @example Fixed root
        #   Graph.draw(wizard) do |g|
        #     g.add_node :start, StartStep
        #     g.root :start  # Always :start
        #   end
        #   graph.root_step  # => :start
        #
        # @example Dynamic root
        #   Graph.draw(wizard) do |g|
        #     g.add_node :simple_path, SimpleStep
        #     g.add_node :complex_path, ComplexStep
        #     g.conditional_root { |state| state.is_complex? ? :complex_path : :simple_path }
        #   end
        #   graph.root_step  # => :simple_path or :complex_path depending on state
        def root_step
          return @registry.root_node if @registry.root_node

          if @registry.conditional_root_block
            @registry.conditional_root_block.call(@wizard.state_store)
          elsif @registry.conditional_root_method
            @wizard.method(@registry.conditional_root_method).call
          end
        end

        # Navigate to next step from current step.
        #
        # Evaluates edges in order:
        # 1. Calls before_next callbacks (can override navigation)
        # 2. Checks custom branching edges
        # 3. Checks multiple conditional edges (N-way branching)
        # 4. Checks conditional edges (if/else)
        # 5. Checks simple edges (linear)
        #
        # @param step [Symbol, nil] Current step (defaults to wizard's current)
        # @return [Symbol, nil] Next step ID or nil if no valid transition
        #
        # @example Basic navigation
        #   graph.next_step(:step1)  # => :step2
        #   graph.next_step(:final)  # => nil (no outgoing edge)
        #
        # @example With conditional
        #   graph.next_step(:visa_check)  # => :student (if eligible) or :worker (if not)
        def next_step(step = nil)
          @resolver.next_step(step)
        end

        # Navigate to previous step.
        #
        # Reverses path traversal to find the previous step in the wizard history.
        # Calls before_previous callbacks before evaluating.
        #
        # @param step [Symbol, nil] Current step (defaults to wizard's current)
        # @return [Symbol, nil] Previous step ID or nil if at root
        #
        # @example Basic navigation
        #   graph.previous_step(:step2)  # => :step1
        #   graph.previous_step(:step1)  # => nil (already at root)
        #
        # @example Prevent going back
        #   Graph.draw(wizard) do |g|
        #     g.before_previous_step { return nil if payment_locked? }
        #   end
        def previous_step(step = nil)
          @resolver.previous_step(step)
        end

        # Calculate the path from root to a target step.
        #
        # Uses graph traversal (BFS) to find all steps between root and target,
        # respecting all edge types and their conditions.
        #
        # Returns empty array if target is unreachable from root.
        #
        # @param target_step [Symbol, nil] Target step (defaults to wizard's current)
        # @return [Array<Symbol>] Path from root to target (empty if unreachable)
        #
        # @example Linear path
        #   graph.path_traversal(:step3)  # => [:step1, :step2, :step3]
        #
        # @example With branching
        #   graph.path_traversal(:student)  # => [:visa_type, :student]
        #   graph.path_traversal(:worker)   # => [:visa_type, :worker]
        #
        # @example Unreachable step
        #   graph.path_traversal(:orphaned)  # => []
        def path_traversal(target_step = nil)
          @resolver.path_traversal(target_step)
        end

        # Find step class by node ID.
        #
        # Returns the step class associated with a node. Used by wizard to
        # instantiate step objects during navigation.
        #
        # Returns nil (never raises) for missing nodes.
        #
        # @param node_id [Symbol] Node identifier
        # @return [Class, nil] The step class or nil if not found
        #
        # @example Existing node
        #   graph.find_step(:personal_info)  # => Steps::PersonalInfoStep
        #
        # @example Missing node
        #   graph.find_step(:missing)  # => nil
        def find_step(node_id)
          @registry.nodes[node_id]&.klass
        end

        # Get all step definitions as a hash.
        #
        # Returns mapping of all node IDs to their step classes.
        # Used for instantiation, validation, and documentation.
        #
        # @return [Hash{Symbol => Class}] { node_id => step_class }
        #
        # @example
        #   graph.step_definitions
        #   # => {
        #   #   personal_info: Steps::PersonalInfoStep,
        #   #   contact: Steps::ContactStep,
        #   #   confirmation: Steps::ConfirmationStep
        #   # }
        def step_definitions
          @registry.nodes.transform_values(&:klass)
        end

        # Generate comprehensive metadata for documentation and visualization.
        #
        # Produces rich hash suitable for:
        # - Markdown documentation generation
        # - Mermaid state/flowchart diagrams
        # - GraphViz DOT visualization
        # - JSON serialization for external tools
        #
        # @return [Hash] Metadata structure with:
        #   - structure_type: :graph
        #   - root_step: Symbol
        #   - steps: { id => { class:, label: } }
        #   - edges: [ { from:, to:, type:, label: } ]
        #   - branch_metadata: { from => { branches: [...], default: } }
        #   - counts: { steps:, edges:, conditional_edges:, etc. }
        #
        # @example
        #   metadata = graph.metadata
        #   # {
        #   #   structure_type: :graph,
        #   #   root_step: :visa_type,
        #   #   steps: {
        #   #     visa_type: { class: VisaTypeStep, label: "Visa Type" },
        #   #     student: { class: StudentStep, label: "Student Details" },
        #   #     worker: { class: WorkerStep, label: "Work Details" }
        #   #   },
        #   #   edges: [
        #   #     { from: :visa_type, to: :student, type: :conditional, label: "Student?" }
        #   #   ],
        #   #   counts: {
        #   #     steps: 3,
        #   #     edges: 1,
        #   #     simple_edges: 0,
        #   #     conditional_edges: 1,
        #   #     multiple_conditional_edges: 0,
        #   #     custom_branching_edges: 0
        #   #   }
        #   # }
        def metadata
          {
            structure_type: :graph,
            root_step: build_root_step,
            steps: build_steps_metadata,
            transitions: build_all_transitions_metadata,
            counts: build_counts_metadata,
          }
        end

        def build_root_step
          @registry.potential_root_nodes.presence || @registry.root_node
        end

        def build_steps_metadata
          @registry.nodes.each_with_object({}) do |(id, node), hash|
            hash[id] = {
              class: node.klass.name,
              label: @registry.step_labels[id],
            }
          end
        end

        def build_all_transitions_metadata(transitions = [])
          @registry.edges.each do |edge|
            transitions << { from: edge.from, to: edge.to, type: :simple, label: nil }
          end

          @registry.conditional_edges.each do |edge|
            transitions << {
              from: edge.from,
              then: edge.then,
              else: edge.else,
              type: :conditional,
              label: edge.label,
            }
          end

          @registry.multiple_conditional_edges.each do |edge|
            transitions << {
              from: edge.from,
              branches: edge.branches.map { |b| { then: b[:then], label: b[:label] } },
              default: edge.default,
              type: :multiple_conditional,
              label: edge.label,
            }
          end

          @registry.custom_branching_edges.each do |edge|
            transitions << {
              from: edge.from,
              type: :custom_branching,
              potential_transitions: edge.potential_transitions,
            }
          end

          transitions
        end

        def build_counts_metadata
          {
            steps: @registry.nodes.size,
            simple_edges: @registry.edges.size,
            conditional_edges: @registry.conditional_edges.size,
            multiple_conditional_edges: @registry.multiple_conditional_edges.size,
            custom_branching_edges: @registry.custom_branching_edges.size,
          }
        end
      end
    end
  end
end
