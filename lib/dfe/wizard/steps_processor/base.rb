module DfE
  module Wizard
    module StepsProcessor
      # Abstract base class for all steps processors.
      #
      # All wizard steps processors must inherit from this class and implement
      # the 8 required methods. This ensures a consistent interface for different
      # data structures (Graph, Linear, StateMachine, etc.) while allowing each
      # to maintain its own DSL and internal logic.
      #
      # @abstract Subclass and implement all required methods
      # @author DfE Wizard Steps Processor Team
      #
      # @example Creating a new processor
      #   class MyProcessor < StepsProcessor::Base
      #     def initialize(wizard, context: nil)
      #       @wizard = wizard
      #       @context = context
      #       @structure = {} # Your structure here
      #     end
      #
      #     def root_step
      #       :my_root
      #     end
      #
      #     # ... implement other 7 methods
      #   end
      #
      # @example Using a processor
      #   processor = Graph.draw(wizard, predicate_caller: state_store) do |g|
      #     g.add_node :step1, StepOne
      #     g.add_node :step2, StepTwo
      #   end
      #
      #   processor.next_step(:step1)     # => :step2
      #   processor.metadata              # => { structure_type: :graph, ... }
      class Base
        # Initialize the steps processor with wizard and optional context.
        #
        # This method should set up all internal data structures specific to
        # the processor type (Graph Registry, Linear array, StateMachine states, etc).
        #
        # @param wizard [Object] The wizard instance
        #   - Must respond to `current_step_name` (current step ID)
        #   - May respond to other methods used in predicates/conditions
        #
        # @param context [Object, nil] Optional context object for evaluating conditions
        #   - Used for conditional logic (predicates, state checks)
        #   - Example: StateStore, entity with business logic
        #   - If nil, only unconditional navigation is possible
        #
        # @return [void]
        #
        # @raise [NotImplementedError] If called on Base class directly
        #
        # @example Graph processor initialization
        #   def initialize(wizard, context: nil)
        #     @wizard = wizard
        #     @context = context
        #     @registry = Registry.new  # Graph-specific
        #     @resolver = nil
        #   end
        #
        # @example Linear processor initialization
        #   def initialize(wizard, context: nil)
        #     @wizard = wizard
        #     @context = context
        #     @steps_array = []       # Linear-specific
        #     @step_classes = {}
        #   end
        def initialize(wizard, context: nil)
          raise NotImplementedError, 'Subclass must implement #initialize'
        end

        # Evaluate and return the root (starting) step for this wizard.
        #
        # The root step can be:
        #
        # - **Fixed:** Always returns the same step ID (e.g., Linear always returns first)
        # - **Dynamic:** Evaluates context/conditions to determine root (e.g., Graph with conditional_root)
        #
        # This method is called:
        #   - When initializing path traversal
        #   - When calculating previous_step from first step
        #   - When generating metadata
        #   - When validating the structure
        #
        # @return [Symbol] The root step ID
        #
        # @raise [NotImplementedError] If called on Base class directly
        # @raise [ArgumentError] If root is not configured/valid
        #
        # @example Graph processor (dynamic root)
        #   def root_step
        #     @registry.entry_point.current_root(@context)
        #   end
        #
        # @example Linear processor (fixed root - always first)
        #   def root_step
        #     @steps_array.first
        #   end
        #
        # @example StateMachine processor (configured initial state)
        #   def root_step
        #     @initial_state
        #   end
        def root_step
          raise NotImplementedError, 'Subclass must implement #root_step'
        end

        # Navigate to the next step from the given step.
        #
        # This method:
        # 1. Uses provided step or defaults to current_step_name from wizard
        # 2. Calls before_next callbacks (if any registered via DSL)
        # 3. Evaluates transitions using structure-specific logic
        # 4. Returns next step ID or nil if terminal/unreachable
        #
        # @param step [Symbol, nil] The step to navigate from
        #   - If nil, defaults to @wizard.current_step_name
        #   - Must be a valid step ID in this processor
        #
        # @return [Symbol, nil]
        #   - Returns next step ID if one exists
        #   - Returns nil if at terminal/exit step (no outgoing transitions)
        #   - Returns nil if step not found
        #
        # @raise [NotImplementedError] If called on Base class directly
        #
        # @example Graph processor
        #   def next_step(step = nil)
        #     current = step || @wizard.current_step_name
        #     result = call_before_next_callbacks
        #     return result if result
        #     @resolver ||= NavigationResolver.new(@registry.transitions, @context)
        #     @resolver.next_step(current)
        #   end
        #
        # @example Linear processor
        #   def next_step(step = nil)
        #     current = step || @wizard.current_step_name
        #     result = call_before_next_callbacks
        #     return result if result
        #     current_index = @steps_array.index(current)
        #     return nil unless current_index
        #     @steps_array[current_index + 1]
        #   end
        def next_step(step = nil)
          raise NotImplementedError, 'Subclass must implement #next_step'
        end

        # Navigate to the previous step from the given step.
        #
        # This method:
        # 1. Uses provided step or defaults to current_step_name from wizard
        # 2. Calls before_previous callbacks (if any registered via DSL)
        # 3. Calculates previous step using structure-specific logic
        # 4. Returns previous step ID or nil if at root/unreachable
        #
        # For most processors, this can be implemented by getting the path
        # from root to current, then returning the second-to-last step.
        #
        # @param step [Symbol, nil] The step to navigate from
        #   - If nil, defaults to @wizard.current_step_name
        #   - Must be a valid step ID in this processor
        #
        # @return [Symbol, nil]
        #   - Returns previous step ID if not at root
        #   - Returns nil if at root step
        #   - Returns nil if step not found
        #
        # @raise [NotImplementedError] If called on Base class directly
        #
        # @example Graph processor (uses NavigationResolver)
        #   def previous_step(step = nil)
        #     current = step || @wizard.current_step_name
        #     result = call_before_previous_callbacks
        #     return result if result
        #     @resolver ||= NavigationResolver.new(@registry.transitions, @context)
        #     @resolver.previous_step(current, self)
        #   end
        #
        # @example Linear processor (just go to previous index)
        #   def previous_step(step = nil)
        #     current = step || @wizard.current_step_name
        #     result = call_before_previous_callbacks
        #     return result if result
        #     current_index = @steps_array.index(current)
        #     return nil unless current_index && current_index > 0
        #     @steps_array[current_index - 1]
        #   end
        def previous_step(step = nil)
          raise NotImplementedError, 'Subclass must implement #previous_step'
        end

        # Calculate and return the complete path from root to target step.
        #
        # This method:
        # 1. Starts from root_step
        # 2. Follows transitions step by step toward target
        # 3. Returns array of all steps visited along the path
        # 4. Returns empty array if target is unreachable
        #
        # Used by:
        # - Visualizations (progress bars, breadcrumbs, step indicators)
        # - Validation (is this step reachable?)
        # - Mermaid diagram generation (highlight traversed path)
        # - Analytics (track user journey)
        #
        # @param target_step [Symbol] The target step ID
        #   - Should be a valid step ID in this processor
        #   - Can be any step, not just exit steps
        #
        # @return [Array<Symbol>]
        #   - Array of step IDs from root to target (inclusive)
        #   - Example: [:step_a, :step_b, :step_c]
        #   - Empty array [] if target is unreachable or not found
        #   - Should include root_step as first element
        #   - Should include target_step as last element (if reachable)
        #
        # @raise [NotImplementedError] If called on Base class directly
        #
        # @example Graph processor
        #   def path_traversal(target_step)
        #     @resolver ||= NavigationResolver.new(@registry.transitions, @context)
        #     @resolver.path_traversal(target_step, self)
        #   end
        #
        # @example Linear processor
        #   def path_traversal(target_step)
        #     target_index = @steps_array.index(target_step)
        #     return [] unless target_index
        #     @steps_array[0..target_index]
        #   end
        def path_traversal(target_step)
          raise NotImplementedError, 'Subclass must implement #path_traversal'
        end

        # Find and return the step class for a given step ID.
        #
        # Used by the wizard framework to:
        # - Instantiate step objects during rendering
        # - Validate step definitions
        # - Generate metadata
        # - Support step introspection
        #
        # @param step_id [Symbol] The step identifier to look up
        #   - Must match a step ID registered via DSL (e.g., add_node, add_step)
        #   - Case-sensitive symbol comparison
        #
        # @return [Class, nil]
        #   - Returns the step class if found
        #   - Returns nil if step_id not found
        #   - Should never raise (return nil for missing steps)
        #
        # @raise [NotImplementedError] If called on Base class directly
        #
        # @example Graph processor
        #   def find_step(step_id)
        #     @registry.steps[step_id]
        #   end
        #
        # @example Linear processor
        #   def find_step(step_id)
        #     @step_classes[step_id]
        #   end
        def find_step(step_id)
          raise NotImplementedError, 'Subclass must implement #find_step'
        end

        # Return a hash of all step definitions in this processor.
        #
        # Format: { step_id => step_class }
        #
        # Used by:
        # - Step instantiation (wizard iterates to find current step class)
        # - Validation (ensure all transitions reference existing steps)
        # - Metadata generation (build step registry)
        # - Step inspection tools
        # - Documentation generation
        #
        # @return [Hash{Symbol => Class}]
        #   - Keys are step IDs (symbols)
        #   - Values are step classes (Class objects)
        #   - Example: { personal_details: PersonalDetailsStep, visa_type: VisaTypeStep }
        #   - Should be immutable or defensive copy
        #   - Empty hash {} if no steps defined yet
        #
        # @raise [NotImplementedError] If called on Base class directly
        #
        # @example Graph processor
        #   def step_definitions
        #     @registry.steps
        #   end
        #
        # @example Linear processor
        #   def step_definitions
        #     @step_classes
        #   end
        def step_definitions
          raise NotImplementedError, 'Subclass must implement #step_definitions'
        end

        # Generate and return comprehensive metadata for insight.
        #
        # This can be used for creating documentation in multiple formats:
        # - Markdown (for wikis, READMEs, design docs)
        # - Mermaid (for embedded flowcharts)
        # - GraphViz (for professional diagrams)
        #
        # The returned hash contains all information needed to fully recreate
        # visual and textual representations of the wizard flow.
        #
        # @return [Hash] Comprehensive metadata with the following structure:
        #
        #   {
        #     # BASICS - Processor & wizard identification
        #     structure_type: :graph | :linear | :state_machine,
        #     wizard_name: "Visa Application",
        #
        #     # TOPOLOGY - Navigation structure
        #     root_step: :personal_details,
        #     exit_steps: [:confirmation, :rejection],
        #     steps: {
        #       personal_details: "Personal Details Step",
        #       visa_type: "Visa Type Selection",
        #       ...
        #     },
        #
        #     # TRANSITIONS - All edges in the graph (for Mermaid/GraphViz)
        #     transitions: [
        #       {
        #         from: :personal_details,
        #         to: :country_of_origin,
        #         type: :unconditional,          # Type of transition
        #         label: nil                     # Display label for diagrams
        #       },
        #       {
        #         from: :visa_type,
        #         to: :student_details,
        #         type: :conditional,            # Binary decision
        #         label: "if student_visa?",
        #         condition: :student_visa?      # Method/logic reference
        #       },
        #       {
        #         from: :visa_type,
        #         to: :family_details,
        #         type: :multi_conditional,      # N-way branch
        #         label: "default",
        #         branches: 3                    # Number of branches
        #       },
        #       {
        #         from: :router,
        #         to: :unknown,
        #         type: :custom,                 # Custom logic
        #         label: "Custom Router",
        #         potential_targets: [:a, :b]   # Possible outcomes
        #       }
        #     ],
        #
        #     # STATISTICS - Aggregated data for dashboards
        #     counts: {
        #       steps: 14,
        #       transitions: 12,
        #       unconditional_transitions: 8,
        #       conditional_transitions: 2,
        #       multi_conditional_transitions: 1,
        #       custom_transitions: 1,
        #       exit_points: 2
        #     },
        #
        #     # STRUCTURE-SPECIFIC - Optional, based on processor type
        #     # Include only fields relevant to this structure
        #
        #     # For Graph processors:
        #     graph_metadata: {
        #       conditional_branches: 3,
        #       max_depth: 7,
        #       parallel_paths: 3
        #     },
        #
        #     # For Linear processors:
        #     linear_metadata: {
        #       sequential: true,
        #       forward_only: true,
        #       skippable_steps: []
        #     },
        #
        #     # For StateMachine processors:
        #     state_metadata: {
        #       states: [:initial, :processing, :final],
        #       events: [:start, :complete, :fail],
        #       initial_state: :initial,
        #       final_states: [:final],
        #       error_states: [:error]
        #     }
        #   }
        #
        # @raise [NotImplementedError] If called on Base class directly
        #
        # @example Graph processor metadata generation
        #   def metadata
        #     @registry.validate!
        #     {
        #       structure_type: :graph,
        #       wizard_name: @wizard.class.name,
        #       root_step: root_step,
        #       exit_steps: find_exit_steps,
        #       steps: step_definitions_with_labels,
        #       transitions: build_transitions_metadata,
        #       counts: calculate_counts,
        #       graph_metadata: calculate_graph_metadata
        #     }
        #   end
        def metadata
          raise NotImplementedError, 'Subclass must implement #metadata'
        end

        # Validate the processor's structure and configuration.
        #
        # Each processor type has its own validation rules:
        #
        # - **Graph:** All edges point to existing steps, root configured
        # - **Linear:** All steps in array, no gaps, root is first
        # - **StateMachine:** All transitions valid, initial state defined, no circular deps
        # - Custom rules as needed for each structure
        #
        # Called automatically by draw() class method after DSL block.
        #
        # @return [void]
        #
        # @raise [ArgumentError] If validation fails with descriptive message
        #   - Should specify what is invalid and why
        #   - Should suggest how to fix (e.g., "add missing edge from :step_a to :step_b")
        #
        # @raise [NotImplementedError] If called on Base class directly
        #
        # @example Graph processor validation
        #   def validate!
        #     @registry.validate!  # Delegates to registry
        #   end
        #
        # @example Linear processor validation
        #   def validate!
        #     raise ArgumentError, "No steps defined" if @steps_array.empty?
        #     raise ArgumentError, "Duplicate steps" if @steps_array.uniq.size != @steps_array.size
        #   end
        def validate!
          raise NotImplementedError, 'Subclass must implement #validate!'
        end

        # Build and return the DSL builder instance for this processor.
        #
        # Each processor type has its own DSL with methods appropriate for
        # that structure. This method returns an instance of the DSL builder.
        #
        # @return [Object] DSL builder instance with structure-specific methods
        #   - Graph: Graph::DSL (add_node, add_edge, add_conditional_edge, etc.)
        #   - Linear: Linear::DSL (add_step)
        #   - StateMachine: StateMachine::DSL (add_state, add_transition, etc.)
        #
        # @raise [NotImplementedError] If called on Base class directly
        #
        # @example Graph processor DSL
        #   def dsl
        #     Graph::DSL.new(self)
        #   end
        def dsl
          raise NotImplementedError, 'Subclass must implement #dsl'
        end

        # ====================================================================
        # CLASS METHODS - Factory & Builder
        # ====================================================================

        # Factory method: Create a processor instance with DSL builder support.
        #
        # Usage pattern:
        # 1. Create processor instance (calls initialize)
        # 2. Yield DSL to block (user configures with DSL methods)
        # 3. Validate processor structure
        # 4. Return configured processor
        #
        # @param wizard [Object] Wizard instance
        # @param context [Object, nil] Optional context for conditions
        #
        # @yield [dsl] Yields the DSL builder to the block
        #   - Block receives processor.dsl instance
        #   - Block uses DSL methods to build processor (add_node, add_step, etc.)
        #
        # @return [Base] Configured and validated processor instance
        #
        # @raise [ArgumentError] If validation fails
        #
        # @example
        #   processor = Graph.draw(wizard, predicate_caller: state_store) do |g|
        #     g.add_node :step1, StepOne
        #     g.add_node :step2, StepTwo
        #     g.root :step1
        #     g.add_edge from: :step1, to: :step2
        #   end
        def self.draw(wizard, context: nil)
          processor = new(wizard, context: context)
          yield(processor.dsl) if block_given?
          processor.validate!
          processor
        end

        # ====================================================================
        # CALLBACKS - Hooks for custom navigation logic
        # ====================================================================

        # Register a callback to execute before navigating to next step.
        #
        # Callbacks are useful for:
        # - Validation before moving forward
        # - Side effects (logging, analytics, state updates)
        # - Conditional route overrides
        #
        # Callbacks are called IN ORDER added. First callback returning non-nil
        # value overrides normal transition logic.
        #
        # @param callback [Proc] Callback to execute
        #   - Called with no arguments
        #   - Executes in context of wizard (can call wizard methods)
        #   - Return non-nil to override normal navigation
        #   - Return nil to continue with normal logic
        #
        # @return [void]
        #
        # @example Validation callback
        #   processor.add_before_next_callback do
        #     return nil  # Continue normally
        #   end
        #
        # @example Override callback
        #   processor.add_before_next_callback do
        #     return :error_step if some_condition_failed?
        #     nil  # Otherwise continue normally
        #   end
        def add_before_next_callback(callback)
          @before_next_callbacks ||= []
          @before_next_callbacks << callback
        end

        # Register a callback to execute before navigating to previous step.
        #
        # See {#add_before_next_callback} for usage details.
        #
        # @param callback [Proc] Callback to execute
        #   - Called with no arguments
        #   - Return non-nil to override normal navigation
        #   - Return nil to continue with normal logic
        #
        # @return [void]
        #
        # @example
        #   processor.add_before_previous_callback do
        #     return nil  # Always allow going back
        #   end
        def add_before_previous_callback(callback)
          @before_previous_callbacks ||= []
          @before_previous_callbacks << callback
        end

        # Execute all registered before_next callbacks.
        #
        # Callbacks are called in order. First callback returning non-nil stops
        # execution and returns that value (overriding normal logic).
        #
        # @return [Symbol, nil]
        #   - Returns non-nil if any callback returned a step ID (override)
        #   - Returns nil if all callbacks returned nil (continue normally)
        #
        # @api public
        def call_before_next_callbacks
          (@before_next_callbacks || []).each do |callback|
            result = callback.call
            return result unless result.nil?
          end
          nil
        end

        # Execute all registered before_previous callbacks.
        #
        # See {#call_before_next_callbacks} for behavior details.
        #
        # @return [Symbol, nil]
        #   - Returns non-nil if any callback returned a step ID (override)
        #   - Returns nil if all callbacks returned nil (continue normally)
        #
        # @api public
        def call_before_previous_callbacks
          (@before_previous_callbacks || []).each do |callback|
            result = callback.call
            return result unless result.nil?
          end
          nil
        end
      end
    end
  end
end
