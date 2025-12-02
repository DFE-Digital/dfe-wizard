module DfE
  module Wizard
    module StepsProcessor
      class Linear < Base
        # DSL builder for Linear steps processor.
        #
        # The Linear DSL provides a fluent interface for building sequential,
        # fixed-order wizard flows. Each step follows the previous one with no
        # branching or conditional logic.
        #
        # @author DfE Wizard Steps Processor Team
        #
        # @example Simple sequential flow
        #   Linear.draw(wizard) do |l|
        #     l.add_step :personal_details, PersonalDetailsStep
        #     l.add_step :country_of_origin, CountryOfOriginStep
        #     l.add_step :visa_type, VisaTypeStep
        #     l.add_step :confirmation, ConfirmationStep
        #   end
        #
        # @example With display labels for documentation
        #   Linear.draw(wizard) do |l|
        #     l.add_step :personal_details, PersonalDetailsStep, label: "Personal Details"
        #     l.add_step :visa_type, VisaTypeStep, label: "Choose Visa Type"
        #   end
        #
        # @example Mark exit/terminal steps
        #   Linear.draw(wizard) do |l|
        #     l.add_step :step1, Step1, exit: false
        #     l.add_step :step2, Step2, exit: false
        #     l.add_step :confirmation, ConfirmationStep, exit: true  # Terminal
        #   end
        #
        # @example Register callbacks for custom behavior
        #   Linear.draw(wizard) do |l|
        #     l.add_step :payment, PaymentStep
        #     l.before_next(:payment) do
        #       return :error if payment_failed?
        #       nil  # Continue normally
        #     end
        #   end
        class DSL
          # Initialize the Linear DSL builder.
          #
          # @param processor [Linear] The Linear processor instance
          # @api private
          def initialize(processor)
            @processor = processor
          end

          # Add a step to the linear sequence.
          #
          # Steps are added in order and will be traversed sequentially.
          # The first step added becomes the root step. The last step added
          # becomes the exit step (unless marked otherwise).
          #
          # @param step_id [Symbol] Unique identifier for this step
          #   - Used in navigation (next_step, previous_step)
          #   - Should be lowercase with underscores (snake_case)
          #   - Must be unique within this processor
          #   - Used in metadata and documentation
          #
          # @param step_class [Class] The step class to instantiate
          #   - Should inherit from Step (or respond to step interface)
          #   - Used by wizard to render the step
          #
          # @param label [String, nil] Human-readable name for documentation
          #   - Used in Markdown, Mermaid, and GraphViz output
          #   - If nil, label defaults to humanized step_id
          #   - Example: :personal_details => "Personal Details"
          #
          # @param exit [Boolean] Mark this step as a terminal/exit step
          #   - If true, next_step returns nil (no further navigation)
          #   - If false, step is not terminal
          #   - Default: false (only last step is exit by default)
          #   - Can have multiple exit steps if needed
          #
          # @return [self] For method chaining
          #
          # @raise [ArgumentError] If step_id already added or invalid
          #
          # @example Basic step
          #   l.add_step :step1, StepOneClass
          #
          # @example With custom label
          #   l.add_step :personal_details, PersonalDetailsStep, label: "Tell us about yourself"
          #
          # @example Mark as exit point
          #   l.add_step :confirmation, ConfirmationStep, exit: true
          #
          # @example Chaining multiple steps
          #   l.add_step(:step1, Step1)
          #    .add_step(:step2, Step2)
          #    .add_step(:step3, Step3)
          def add_step(step_id, step_class, label: nil, exit: false)
            raise ArgumentError, 'Step ID must be a symbol' unless step_id.is_a?(Symbol)
            raise ArgumentError, 'Step class must be a Class' unless step_class.is_a?(Class)
            raise ArgumentError, "Step ID #{step_id} already added" if step_already_added?(step_id)

            @processor.add_step(step_id, step_class, label: label, exit: exit)
            self
          end

          # Set the root (starting) step for this linear sequence.
          #
          # By default, the first step added becomes the root. Use this method
          # to override that behavior and specify a different starting step.
          #
          # The root step must already be added via add_step.
          #
          # @param step_id [Symbol] The step to start from
          #   - Must be a valid step ID (already added)
          #   - Will become the first step in navigation
          #
          # @return [self] For method chaining
          #
          # @raise [ArgumentError] If step_id not found or not added yet
          #
          # @example Override default root
          #   l.add_step :welcome, WelcomeStep
          #   l.add_step :form, FormStep
          #   l.root :welcome  # Start from welcome (default anyway)
          #
          # @example Using different root (less common)
          #   # If you need to start from step2 instead of step1
          #   l.add_step :step1, Step1
          #   l.add_step :step2, Step2
          #   l.add_step :step3, Step3
          #   l.root :step2  # Now starts from step2 instead
          def root(step_id)
            raise ArgumentError, 'Root step ID must be a symbol' unless step_id.is_a?(Symbol)
            raise ArgumentError, "Root step #{step_id} not found (add it first)" unless step_exists?(step_id)

            @processor.root = step_id
            self
          end

          # Register a callback to execute before navigating to the next step.
          #
          # Useful for:
          # - Validating current step's data before proceeding
          # - Logging or analytics tracking
          # - force different path
          # - Side effects (update state, send notifications)
          #
          # Callbacks are executed IN ORDER. The first callback returning
          # non-nil stops execution and returns that value (overriding normal navigation).
          #
          # @param step_id [Symbol] Step to add callback to
          #   - Callback executes when navigating FROM this step
          #   - Must be a valid step ID
          #
          # @yield [] Yields control to the block
          #   - Block receives no arguments
          #   - Block should return nil to continue normally
          #   - Block should return a step_id (Symbol) to override navigation
          #
          # @return [self] For method chaining
          #
          # @raise [ArgumentError] If step_id not found
          #
          # @example Validate before proceeding
          #   l.before_next(:payment) do
          #     if amount_valid?
          #       nil  # Continue to next step normally
          #     else
          #       :error_step  # Override and go to error instead
          #     end
          #   end
          #
          # @example Multiple callbacks (execute in order)
          #   l.before_next(:step1) do
          #     log_event(:step1_exit)
          #     nil  # Continue
          #   end
          #
          #   l.before_next(:step1) do
          #     return nil  # This runs second, continue
          #   end
          #
          # @example Register via processor (if needed)
          #   l.before_next(:payment) do
          #     validate_payment!
          #     nil
          #   end
          def before_next(step_id, &)
            raise ArgumentError, 'Step ID must be a symbol' unless step_id.is_a?(Symbol)
            raise ArgumentError, 'before_next block required' unless block_given?
            raise ArgumentError, "Step #{step_id} not found" unless step_exists?(step_id)

            @processor.add_before_next_callback_for_step(step_id, &)
            self
          end

          # Register a callback to execute before navigating to the previous step.
          #
          # See {#before_next} for detailed usage. Same behavior applies,
          # but callback executes when navigating FROM the given step backward.
          #
          # @param step_id [Symbol] Step to add callback to
          #   - Callback executes when navigating BACK from this step
          #
          # @yield [] Yields control to the block
          #   - Block should return nil to continue normally
          #   - Block should return a step_id to override
          #
          # @return [self] For method chaining
          #
          # @example Prevent going back from certain steps
          #   l.before_previous(:payment) do
          #     if payment_already_processed?
          #       nil  # Can go back
          #     else
          #       :stay_here  # Block going back
          #     end
          #   end
          def before_previous(step_id, &)
            raise ArgumentError, 'Step ID must be a symbol' unless step_id.is_a?(Symbol)
            raise ArgumentError, 'before_previous block required' unless block_given?
            raise ArgumentError, "Step #{step_id} not found" unless step_exists?(step_id)

            @processor.add_before_previous_callback_for_step(step_id, &)
            self
          end

          # Set display label for a step (used in documentation).
          #
          # Labels are used in:
          # - Markdown documentation
          # - Mermaid diagrams
          # - GraphViz visualizations
          # - UI breadcrumbs/progress indicators
          #
          # By default, labels are humanized from step IDs:
          # - :personal_details => "Personal Details"
          # - :visa_type => "Visa Type"
          #
          # Use this method to customize the label.
          #
          # @param step_id [Symbol] Step to set label for
          # @param label [String] Human-readable label
          #   - Should be concise (used in diagrams)
          #   - Can include spaces and special characters
          #
          # @return [self] For method chaining
          #
          # @raise [ArgumentError] If step_id not found
          #
          # @example Custom labels
          #   l.label :personal_details, "Tell us about yourself"
          #   l.label :visa_type, "What type of visa do you need?"
          #   l.label :confirmation, "Confirm and submit"
          def label(step_id, label_text)
            raise ArgumentError, 'Step ID must be a symbol' unless step_id.is_a?(Symbol)
            raise ArgumentError, 'Label must be a string' unless label_text.is_a?(String)
            raise ArgumentError, "Step #{step_id} not found" unless step_exists?(step_id)

            @processor.update_label(step_id, label_text)
            self
          end

          # Mark a step as an exit/terminal step.
          #
          # Exit steps are steps where navigation ends. next_step returns nil
          # from an exit step.
          #
          # @param step_id [Symbol] Step to mark as exit
          # @param is_exit [Boolean] Whether this is an exit step
          #   - true: Mark as terminal
          #   - false: Mark as non-terminal
          #
          # @return [self] For method chaining
          #
          # @raise [ArgumentError] If step_id not found
          #
          # @example Mark confirmation as exit
          #   l.add_step :step1, Step1
          #   l.add_step :step2, Step2
          #   l.add_step :confirmation, ConfirmationStep
          #   l.exit :confirmation
          #
          # @example Mark multiple exits
          #   l.exit :confirmation, true
          #   l.exit :error, true
          #   l.exit :cancelled, true
          def exit(step_id, is_exit = true)
            raise ArgumentError, 'Step ID must be a symbol' unless step_id.is_a?(Symbol)
            raise ArgumentError, "Step #{step_id} not found" unless step_exists?(step_id)

            @processor.mark_exit(step_id, is_exit)
            self
          end

          # Set the wizard display name (for documentation).
          #
          # Used in:
          # - Markdown headers
          # - Mermaid diagram titles
          # - GraphViz labels
          #
          # @param name [String] Display name for this wizard
          #   - Examples: "Visa Application", "User Registration"
          #
          # @return [self] For method chaining
          #
          # @example
          #   l.name "Visa Application Wizard"
          def name(wizard_name)
            raise ArgumentError, 'Name must be a string' unless wizard_name.is_a?(String)

            @processor.wizard_name = wizard_name
            self
          end

          # List all added steps in order.
          #
          # Useful for debugging and inspection.
          #
          # @return [Array<Symbol>] Array of step IDs in order
          #
          # @example
          #   l.add_step :step1, Step1
          #   l.add_step :step2, Step2
          #   l.steps  # => [:step1, :step2]
          def steps
            @processor.step_ids
          end

          # Check if a step exists in the processor.
          #
          # @param step_id [Symbol] Step ID to check
          # @return [Boolean] true if step exists, false otherwise
          def step_exists?(step_id)
            @processor.step_ids.include?(step_id)
          end

          # Check if a step was already added (helper for validation).
          #
          # @param step_id [Symbol] Step ID to check
          # @return [Boolean] true if step already added
          # @api private
          def step_already_added?(step_id)
            @processor.step_ids.include?(step_id)
          end
        end
      end
    end
  end
end
