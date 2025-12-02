require_relative 'linear/dsl'

module DfE
  module Wizard
    module StepsProcessor
      # Linear steps processor implementation.
      #
      # The Linear processor manages sequential, fixed-order wizard flows.
      # Steps are visited in the exact order they are added, with no branching
      # or conditional logic.
      #
      # Use Linear for:
      # - Registration forms (step-by-step)
      # - Onboarding flows (guided sequential)
      # - Simple surveys (question by question)
      # - Multi-page forms with fixed order
      #
      # @example Usage
      #   processor = Linear.draw(wizard) do |l|
      #     l.add_step :step1, Step1
      #     l.add_step :step2, Step2
      #     l.add_step :step3, Step3
      #   end
      #
      #   processor.next_step(:step1)  # => :step2
      #   processor.next_step(:step2)  # => :step3
      #   processor.next_step(:step3)  # => nil (terminal)
      class Linear < Base
        attr_reader :wizard, :context

        # Initialize the Linear processor.
        #
        # @param wizard [Object] Wizard instance
        # @param context [Object, nil] Optional context
        def initialize(wizard, context: nil)
          @wizard = wizard
          @context = context
          @steps_array = []              # Ordered list of step IDs
          @step_classes = {}             # { step_id => step_class }
          @step_labels = {}              # { step_id => display_label }
          @exit_steps = Set.new          # Set of exit step IDs
          @root_step_id = nil            # Explicitly set root (default: first added)
          @before_next_callbacks = {}    # { step_id => [callbacks] }
          @before_previous_callbacks = {} # { step_id => [callbacks] }
          @wizard_name = nil # Display name for docs
        end

        # ====================================================================
        # REQUIRED METHODS - Implement Base interface
        # ====================================================================

        # Return the root step for this linear sequence.
        #
        # Default: first step added
        # Can be overridden via DSL root() method
        #
        # @return [Symbol] Root step ID
        # @raise [ArgumentError] If no steps defined
        def root_step
          raise ArgumentError, 'No steps defined' if @steps_array.empty?

          @root_step_id || @steps_array.first
        end

        # Navigate to next step in sequence.
        #
        # @param step [Symbol, nil] Current step (defaults to wizard's current)
        # @return [Symbol, nil] Next step ID or nil if terminal
        def next_step(step = nil)
          current = step || @wizard.current_step_name

          # Check callbacks for override
          result = call_before_next_callbacks_for_step(current)
          return result if result

          # Get current index
          current_index = @steps_array.index(current)
          return nil unless current_index

          # Get next step
          @steps_array[current_index + 1]
        end

        # Navigate to previous step in sequence.
        #
        # @param step [Symbol, nil] Current step (defaults to wizard's current)
        # @return [Symbol, nil] Previous step ID or nil if at root
        def previous_step(step = nil)
          current = step || @wizard.current_step_name

          # Check callbacks for override
          result = call_before_previous_callbacks_for_step(current)
          return result if result

          # Get current index
          current_index = @steps_array.index(current)
          return nil unless current_index&.positive?

          # Get previous step
          @steps_array[current_index - 1]
        end

        # Calculate path from root to target step.
        #
        # @param target_step [Symbol] Target step ID
        # @return [Array<Symbol>] Path from root to target (empty if unreachable)
        def path_traversal(target_step)
          target_index = @steps_array.index(target_step)
          return [] unless target_index

          @steps_array[0..target_index]
        end

        # Find step class by ID.
        #
        # @param step_id [Symbol] Step ID
        # @return [Class, nil] Step class or nil
        def find_step(step_id)
          @step_classes[step_id]
        end

        # Return all step definitions.
        #
        # @return [Hash{Symbol => Class}] { step_id => step_class }
        def step_definitions
          @step_classes.dup
        end

        # Generate metadata for documentation.
        #
        # @return [Hash] Comprehensive metadata
        def metadata
          validate!

          {
            structure_type: :linear,
            wizard_name: @wizard_name || @wizard.class.name,
            root_step: root_step,
            exit_steps: @exit_steps.to_a,
            steps: build_steps_metadata,
            transitions: build_transitions_metadata,
            counts: build_counts_metadata,
            linear_metadata: {
              sequential: true,
              forward_only: true,
              skippable_steps: [],
            },
          }
        end

        # Validate linear structure.
        #
        # @raise [ArgumentError] If validation fails
        def validate!
          raise ArgumentError, 'No steps defined in Linear processor' if @steps_array.empty?

          if @steps_array.uniq.size != @steps_array.size
            raise ArgumentError, 'Duplicate step IDs in Linear processor'
          end

          @steps_array.each do |step_id|
            unless @step_classes[step_id]
              raise ArgumentError, "Step #{step_id} has no class defined"
            end
          end

          unless @steps_array.include?(root_step)
            raise ArgumentError, "Root step #{root_step} not in steps array"
          end
        end

        # Return DSL builder instance.
        #
        # @return [DSL] DSL builder
        def dsl
          @dsl ||= DSL.new(self)
        end

        # Add a step to the sequence (called by DSL).
        #
        # @api private
        def add_step(step_id, step_class, label: nil, exit: false)
          @steps_array << step_id
          @step_classes[step_id] = step_class
          @step_labels[step_id] = label || humanize(step_id)
          @exit_steps.add(step_id) if exit
        end

        # Set root step (called by DSL).
        #
        # @api private
        def root=(step_id)
          @root_step_id = step_id
        end

        # Add before_next callback for specific step (called by DSL).
        #
        # @api private
        def add_before_next_callback_for_step(step_id, &block)
          @before_next_callbacks[step_id] ||= []
          @before_next_callbacks[step_id] << block
        end

        # Add before_previous callback for specific step (called by DSL).
        #
        # @api private
        def add_before_previous_callback_for_step(step_id, &block)
          @before_previous_callbacks[step_id] ||= []
          @before_previous_callbacks[step_id] << block
        end

        # Set label for step (called by DSL).
        #
        # @api private
        def update_label(step_id, label_text)
          @step_labels[step_id] = label_text
        end

        # Mark step as exit (called by DSL).
        #
        # @api private
        def mark_exit(step_id, is_exit)
          if is_exit
            @exit_steps.add(step_id)
          else
            @exit_steps.delete(step_id)
          end
        end

        # Set wizard display name (called by DSL).
        #
        # @api private
        attr_writer :wizard_name

        # Get step IDs in order (called by DSL).
        #
        # @api private
        def step_ids
          @steps_array.dup
        end

        # ====================================================================
        # PROTECTED HELPERS
        # ====================================================================

        protected

        # Call before_next callbacks for a specific step.
        #
        # @param step_id [Symbol] Step to get callbacks for
        # @return [Symbol, nil] Override step ID or nil
        def call_before_next_callbacks_for_step(step_id)
          callbacks = @before_next_callbacks[step_id] || []
          callbacks.each do |callback|
            result = callback.call
            return result unless result.nil?
          end
          nil
        end

        # Call before_previous callbacks for a specific step.
        #
        # @param step_id [Symbol] Step to get callbacks for
        # @return [Symbol, nil] Override step ID or nil
        def call_before_previous_callbacks_for_step(step_id)
          callbacks = @before_previous_callbacks[step_id] || []
          callbacks.each do |callback|
            result = callback.call
            return result unless result.nil?
          end
          nil
        end

        # Build steps metadata for documentation.
        #
        # @return [Hash{Symbol => String}] { step_id => display_label }
        def build_steps_metadata
          @steps_array.each_with_object({}) do |step_id, hash|
            hash[step_id] = @step_labels[step_id]
          end
        end

        # Build transitions metadata for Mermaid/GraphViz.
        #
        # @return [Array<Hash>] Array of transition definitions
        def build_transitions_metadata
          @steps_array.each_cons(2).map do |from_step, to_step|
            {
              from: from_step,
              to: to_step,
              type: :unconditional,
              label: nil,
            }
          end
        end

        # Build counts metadata for statistics.
        #
        # @return [Hash] Counts of steps, transitions, etc.
        def build_counts_metadata
          {
            steps: @steps_array.count,
            transitions: @steps_array.count - 1,
            unconditional_transitions: @steps_array.count - 1,
            conditional_transitions: 0,
            multi_conditional_transitions: 0,
            custom_transitions: 0,
            exit_points: @exit_steps.count,
          }
        end

        # Humanize a step ID for display.
        #
        # Converts :step_one_name to "Step One Name"
        #
        # @param step_id [Symbol] Step ID to humanize
        # @return [String] Humanized label
        def humanize(step_id)
          step_id
            .to_s
            .split('_')
            .map(&:capitalize)
            .join(' ')
        end
      end
    end
  end
end
