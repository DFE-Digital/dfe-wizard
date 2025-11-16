# frozen_string_literal: true

module DfE
  module Wizard
    module Core
      # StateStore module: High-level wizard state management with dynamic accessors
      #
      # This module provides:
      # - Reading/writing step data from repository
      # - Managing current_step_params
      # - Dynamically generating accessors from ActiveModel step attributes
      #
      # ## Usage
      #
      #   class PersonalInformationStateStore
      #     include DfE::Wizard::StateStore
      #   end
      #
      #   state_store = PersonalInformationStateStore.new(
      #     repository: DfE::Wizard::Repository::InMemory.new,
      #     current_step_params: params
      #   )
      #
      #   # Later, wizard calls:
      #   state_store.define_accessors_from_steps(wizard.steps_schema)
      #
      #   # Now you can use:
      #   state_store.name_first_name       # getter
      #   state_store.name_first_name = 'John'  # setter
      #   state_store.name_first_name?      # predicate
      #
      # @api public
      module StateStore
        # Included hook
        def self.included(base)
          base.extend ClassMethods
        end

        module ClassMethods
        end

        # Initialize state store
        #
        # @param repository [DfE::Wizard::Repository::*] Backend storage adapter
        # @param current_step_params [Hash] Parameters for the current step (from request)
        # @return [void]
        def initialize(repository:, current_step_params: {})
          @repository = repository
          @current_step_params = current_step_params
          @accessor_cache = {}
        end

        # Access the underlying repository
        #
        # @return [DfE::Wizard::Repository::*]
        attr_reader :repository

        # Parameters for the current step being processed
        #
        # @return [Hash]
        attr_reader :current_step_params

        # Define dynamic accessors from wizard's step schema
        #
        # Introspects each step class and generates methods like:
        #   state_store.name_first_name       # getter
        #   state_store.name_first_name = 'John'  # setter
        #   state_store.name_first_name?      # predicate
        #   state_store.name_attributes       # batch getter
        #   state_store.name_attributes = {}  # batch setter
        #
        # Attributes are extracted from step classes via ActiveModel's attribute_names.
        #
        # @param steps_schema [Hash<Symbol, Class>] Map of step_id => step_class
        # @return [void]
        #
        # @example
        #   state_store.define_accessors_from_steps(
        #     name: Steps::Name,
        #     email: Steps::Email
        #   )
        def define_accessors_from_steps(steps_schema)
          steps_schema.each do |step_id, step_class|
            step_attributes = extract_step_attributes(step_class)
            next if step_attributes.empty?

            define_accessors_for_step(step_id, step_attributes)
          end
        end

        # Extract attribute names from a step class
        #
        # Uses ActiveModel's built-in attribute_names if available.
        #
        # @param step_class [Class] A step class that includes DfE::Wizard::Core::Step
        # @return [Array<Symbol>] List of attribute names
        #
        # @api private
        def extract_step_attributes(step_class)
          return [] unless step_class.respond_to?(:attribute_names)

          step_class.attribute_names.map(&:to_sym)
        end

        # Define all accessors for a single step
        #
        # @param step_id [Symbol] The step identifier
        # @param attribute_names [Array<Symbol>] Attribute names from step class
        # @return [void]
        #
        # @api private
        def define_accessors_for_step(step_id, attribute_names)
          attribute_names.each do |attr_name|
            define_attribute_getter(step_id, attr_name)
            define_attribute_setter(step_id, attr_name)
            define_attribute_predicate(step_id, attr_name)
          end

          define_batch_getter(step_id)
          define_batch_setter(step_id)
        end

        # Define getter: state_store.name_first_name
        #
        # @api private
        def define_attribute_getter(step_id, attr_name)
          method_name = :"#{step_id}_#{attr_name}"
          cache_key = [:getter, step_id, attr_name]

          define_singleton_method(method_name) do
            return @accessor_cache[cache_key] if @accessor_cache.key?(cache_key)

            value = read_step(step_id)[attr_name]
            @accessor_cache[cache_key] = value
            value
          end
        end

        # Define setter: state_store.name_first_name = 'John'
        #
        # @api private
        def define_attribute_setter(step_id, attr_name)
          method_name = :"#{step_id}_#{attr_name}="

          define_singleton_method(method_name) do |value|
            write_step(step_id, { attr_name => value })
            @accessor_cache.delete([:getter, step_id, attr_name])
            value
          end
        end

        # Define predicate: state_store.name_first_name?
        #
        # @api private
        def define_attribute_predicate(step_id, attr_name)
          method_name = :"#{step_id}_#{attr_name}?"

          define_singleton_method(method_name) do
            read_step(step_id)[attr_name].present?
          end
        end

        # Define batch getter: state_store.name_attributes
        #
        # @api private
        def define_batch_getter(step_id)
          method_name = :"#{step_id}_attributes"

          define_singleton_method(method_name) do
            read_step(step_id)
          end
        end

        # Define batch setter: state_store.name_attributes = {...}
        #
        # @api private
        def define_batch_setter(step_id)
          method_name = :"#{step_id}_attributes="

          define_singleton_method(method_name) do |attrs|
            write_step(step_id, attrs)
            @accessor_cache.clear
            attrs
          end
        end

        # Read complete wizard state from repository
        #
        # @return [Hash] All persisted wizard data
        def read
          @repository.read
        end

        # Write data by deep merging with existing state
        #
        # @param hash [Hash] Data to merge into existing state
        # @return [Hash] The merged result
        def write(hash)
          @repository.write(hash)
        end

        # Save data atomically (replaces entire state)
        #
        # @param hash [Hash] Complete state to save
        # @return [Hash] The saved data
        def save(hash)
          @repository.save(hash)
        end

        # Clear all state from repository
        #
        # @return [void]
        def clear
          @repository.clear
          @accessor_cache.clear
        end

        # Read data for a specific step
        #
        # @param step_id [Symbol] The step identifier
        # @return [Hash] Step data or empty hash if not found
        def read_step(step_id)
          read.dig(:steps, step_id) || {}
        end

        # Write data for a specific step (deep merge)
        #
        # Updates only the specified step, preserving all other data.
        #
        # @param step_id [Symbol] The step identifier
        # @param data [Hash] Attributes to merge into step
        # @return [Hash] Updated state
        def write_step(step_id, data)
          current = read
          steps = current[:steps] || {}
          steps[step_id] = (steps[step_id] || {}).deep_merge(data)
          write(current.merge(steps: steps))
        end

        # Save multiple steps atomically
        #
        # Replaces all steps while preserving other state.
        #
        # @param steps_hash [Hash<Symbol, Hash>] Map of step_id => step_data
        # @return [Hash] Updated state
        def save_steps(steps_hash)
          current = read
          write(current.merge(steps: steps_hash))
        end

        # Delete step data from state
        #
        # @param step_id [Symbol] The step identifier
        # @return [Hash] Updated state
        def delete_step(step_id)
          current = read
          steps = current[:steps] || {}
          steps.delete(step_id)
          write(current.merge(steps: steps))
        end

        # Update current step params (deep merge)
        #
        # @param new_params [Hash] Params to merge
        # @return [Hash] Updated params
        def update_current_step_params(new_params)
          @current_step_params = @current_step_params.deep_merge(new_params)
        end

        # Clear current step params
        #
        # @return [void]
        def clear_current_step_params
          @current_step_params = {}
        end
      end
    end
  end
end
