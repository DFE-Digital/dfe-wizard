module DfE
  module Wizard
    module StepsOperator
      # Builds the operations configuration for each step in a wizard.
      #
      # The Builder uses a DSL to define which operations run on each step.
      # If a step is not mentioned, it gets default operations [Validate, Persist].
      #
      # Observation the `use:` option overwrites the whole thing INCLUDING Validation
      # so Validation won't be triggered for that step.
      #
      # @example Define operations for a wizard
      #   def steps_operator
      #     DfE::Wizard::StepsOperator::Builder.draw(wizard: self, callable: state_store) do |builder|
      #       builder.on_step(:what_a_level_is_required, use: [CreateALevel])
      #       builder.on_step(:personal_details, add: [SendEmail])
      #       builder.on_step(:review, use: [])
      #     end
      #   end
      #
      # @example Use operations
      #   operations = builder.operations_for(:what_a_level_is_required)
      #   # => [Validate, CreateALevel, Persist]
      #
      class Builder
        # @return [DfE::Wizard::StepsOperator::Config] The configuration object
        attr_reader :config

        # @return [Object] The callable object that will be call to execute
        # operations.
        attr_reader :callable

        # Default operations applied to all steps
        DEFAULT_OPERATIONS = [Operations::Validate, Operations::Persist].freeze

        # Initialize the builder
        #
        # @param wizard [DfE::Wizard] The wizard instance
        # @param callable [Object] The state_store or repository (used for operation context)
        def initialize(wizard:, callable: nil)
          @wizard = wizard
          @callable = callable || wizard.state_store
          @config = Config.new
        end

        # Draw the operations configuration using DSL
        #
        # @param wizard [DfE::Wizard] The wizard instance
        # @param callable [Object] The state_store or repository
        # @yield [builder] The builder instance for DSL usage
        #
        # @example
        #   DfE::Wizard::StepsOperator::Builder.draw(wizard: my_wizard, callable: my_state_store) do |b|
        #     b.on_step(:step_name, use: [MyOp])
        #   end
        #
        # @return [Builder] The configured builder
        def self.draw(wizard:, callable:)
          builder = new(wizard: wizard, callable: callable)
          yield(builder)
          builder
        end

        # Configure operations for a specific step
        #
        # @param step_name [Symbol] The name of the step
        # @param use [Array<Class>] Explicitly set operations (replaces ALL defaults)
        # @param add [Array<Class>] Add operations to defaults (rare)
        #
        # @example Replace defaults entirely (so validation is not triggered!)
        #   builder.on_step(:what_a_level_is_required, use: [CreateALevel])
        #
        # @example Replace with explicit list including Validate
        #   builder.on_step(:what_a_level_is_required, use: [Validate, CreateALevel])
        #
        # @example Add to defaults (rare)
        #   builder.on_step(:personal_details, add: [SendEmail, LogEvent])
        #
        # @example Run no operations
        #   builder.on_step(:review, use: [])
        #
        # @return [void]
        def on_step(step_name, use: nil, add: nil)
          if use.nil? && add.nil?
            raise ArgumentError, "on_step requires either 'use:' or 'add:' keyword argument"
          end

          if use && add
            raise ArgumentError, "on_step cannot accept both 'use:' and 'add:'"
          end

          if use
            @config.set_operations(step_name, use)
          elsif add
            merged_ops = DEFAULT_OPERATIONS + add
            @config.set_operations(step_name, merged_ops)
          end
        end

        # Get operations for a specific step
        #
        # @param step_name [Symbol] The name of the step
        #
        # @example
        #   operations = builder.operations_for(:what_a_level_is_required)
        #   # => [#<Validate>, #<CreateALevel>, #<Persist>]
        #
        # @return [Array<Class>] Array of operation classes
        def operations_for(step_name)
          @config.operations_for(step_name) || DEFAULT_OPERATIONS.dup
        end

        # Get all configured operations
        #
        # @example
        #   all_ops = builder.all_operations
        #   # => { what_a_level_is_required: [...], personal_details: [...] }
        #
        # @return [Hash{Symbol => Array<Class>}] All configured operations by step
        def all_operations
          @config.all_operations
        end
      end

      # Internal configuration storage
      # @private
      class Config
        def initialize
          @operations_map = {}
        end

        def set_operations(step_name, operations)
          @operations_map[step_name] = operations.dup.freeze
        end

        def operations_for(step_name)
          @operations_map[step_name]
        end

        def all_operations
          @operations_map.dup
        end
      end
    end
  end
end
