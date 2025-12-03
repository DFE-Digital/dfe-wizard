module DfE
  module Wizard
    module Core
      # Unified metadata aggregator that enriches processor metadata with step details.
      #
      # Combines:
      # 1. Processor metadata (structure, steps, transitions)
      # 2. Step attributes (from ActiveModel::Attributes)
      # 3. Step validators (from ActiveModel::Validations)
      # 4. Step operations (from StepsOperator DSL)
      #
      # @example
      #   wizard = MyWizard.new
      #   metadata = Core::Metadata.new(wizard)
      #   metadata.to_h
      #   # => {
      #   #      structure_type: :graph,
      #   #      steps: {
      #   #        step_id: {
      #   #          label: '...',
      #   #          class: '...',
      #   #          attributes: [{name:, type:,}],
      #   #          validators: [{name:, type:, message:}],
      #   #          operations: [{name:, hook:, description:}]
      #   #        }
      #   #      }
      #   #    }
      class Metadata
        # Initialize metadata extractor and aggregator
        #
        # @param wizard [DfE::Wizard::Base] The wizard instance
        # @raise [ArgumentError] If wizard doesn't have steps_processor or metadata
        def initialize(wizard)
          @wizard = wizard
          validate_wizard!

          @enriched_metadata = nil
        end

        # Get complete enriched metadata
        #
        # @return [Hash] Enriched metadata with all three layers
        def to_h
          @enriched_metadata ||= begin
            metadata = @wizard.steps_processor.metadata.deep_dup
            enrich_with_step_details(metadata)
            metadata
          end
        end

        # Alias for to_h
        def to_hash
          to_h
        end

        # Hash-like bracket access
        #
        # @param key [Symbol, String] Metadata key
        # @return [Object] Value for key or nil
        def [](key)
          to_h[key.to_sym]
        end

        # Check if key exists in metadata
        #
        # @param key [Symbol, String] Metadata key
        # @return [Boolean] True if key exists
        def key?(key)
          to_h.key?(key.to_sym)
        end

        # Iterate over metadata key-value pairs
        #
        # @yield [key, value] Metadata entries
        # @return [Enumerator, nil] Enumerator if no block given
        def each(&)
          if block_given?
            to_h.each(&)
          else
            to_h.each
          end
        end

        private

        # Validate wizard has required interfaces
        #
        # @raise [ArgumentError] If wizard invalid
        def validate_wizard!
          raise ArgumentError, 'Wizard must have steps_processor method' unless @wizard.respond_to?(:steps_processor)

          processor = @wizard.steps_processor
          unless processor.respond_to?(:metadata)
            raise ArgumentError,
                  'Wizard.steps_processor must have metadata method'
          end
        end

        # Enrich metadata with step details (attributes, validators, operations)
        #
        # @param metadata [Hash] Processor metadata to enrich
        # @return [void] Modifies metadata in place
        def enrich_with_step_details(metadata)
          @enriched_metadata = metadata

          metadata[:steps].each do |step_id, step_data|
            step_class = find_step_class(step_id)

            if step_class
              step_data[:attributes] = extract_step_attributes(step_class)
              step_data[:validators] = extract_step_validators(step_class)
              step_data[:operations] = extract_step_operations(step_id)
            else
              # Graceful fallback for missing classes
              step_data[:attributes] = []
              step_data[:validators] = []
              step_data[:operations] = []
            end
          end
        end

        # Find step class from metadata
        #
        # @param step_id [Symbol] Step identifier
        # @return [Class, nil] Step class or nil if not found
        def find_step_class(step_id)
          step_data = @enriched_metadata[:steps][step_id]
          return nil unless step_data

          class_ref = step_data[:class]
          return nil unless class_ref

          case class_ref
          when String
            class_ref.constantize
          when Class
            class_ref
          end
        rescue StandardError
          nil
        end

        # Extract attributes from step class
        #
        # @param step_class [Class] Step class
        # @return [Array<Hash>] Array of attribute hashes
        def extract_step_attributes(step_class)
          return [] unless step_class.respond_to?(:attribute_types)

          step_class.attribute_types.map do |name, type|
            {
              name: name.to_sym,
              type: type.class || type,
            }
          end
        end

        # Extract validators from step class
        #
        # @param step_class [Class] Step class
        # @return [Array<Hash>] Array of validator hashes
        def extract_step_validators(step_class)
          return [] unless step_class.respond_to?(:_validators)

          validators = []

          step_class._validators.each do |attr_name, validator_array|
            validator_array.each do |validator|
              validators << {
                name: attr_name.to_sym,
                class: validator.class.name,
                type: validator_name(validator),
                message: validator.options[:message],
              }
            end
          end

          validators
        end

        # Extract validator type from validator instance
        #
        # @param validator [ActiveModel::Validator] Validator instance
        # @return [Symbol] Validator type
        def validator_name(validator)
          validator.class.name
                   .demodulize
                   .underscore
                   .sub(/_validator$/, '')
                   .to_sym
        end

        # Extract operations for step
        #
        # @param step_id [Symbol] Step identifier
        # @return [Array<Hash>] Array of operation hashes
        def extract_step_operations(step_id)
          return [] unless @wizard.respond_to?(:steps_operator)

          steps_operator = @wizard.steps_operator
          operation_classes = steps_operator.operations_for(step_id)

          return [] unless operation_classes

          operation_classes.map do |op_class|
            description = if op_class.respond_to?(:description)
                            op_class.description
                          else
                            "#{op_class.name.demodulize} operation"
                          end

            {
              name: op_class.name.demodulize.underscore.to_sym,
              description:,
            }
          end
        end
      end
    end
  end
end
