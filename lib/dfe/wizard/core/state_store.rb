module DfE
  module Wizard
    module Core
      # StateStore module: High-level wizard state management with dynamic accessors
      #
      # This module provides:
      # - Reading/writing step data from repository
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
      #   )
      #
      #   # Later, wizard calls during initialization:
      #   state_store.define_step_attributes_methods(wizard)
      #
      #   # Now you can use auto-generated methods:
      #   state_store.first_name       # getter
      #   state_store.email            # getter
      #   state_store.has_previous_names?  # custom predicate (not overwritten)
      #
      # @api public
      module StateStore
        # Initialize state store
        #
        # @param repository [DfE::Wizard::Repository::*] Backend storage adapter
        # @return [void]
        def initialize(repository: DfE::Wizard::Repository::InMemory.new)
          @repository = repository
        end

        # Access the underlying repository
        #
        # @return [DfE::Wizard::Repository::*]
        attr_reader :repository

        # Called during wizard initialization to dynamically define methods
        # based on step definitions from the wizard's graph.
        #
        # @param wizard [DfE::Wizard] The wizard instance to introspect
        # @return [void]
        #
        # @example Generated methods
        #   # For step :email with attributes [:email, :confirmed]
        #   def email
        #     read.dig(:steps, :email, :email)
        #   end
        #
        #   def confirmed
        #     read.dig(:steps, :email, :confirmed)
        #   end
        #
        # @note Methods are defined as singleton methods on the state_store instance
        # @note Skips attributes that would conflict with existing methods
        # @note Only generates readers, not writers
        #
        # @api public
        def define_step_attributes_methods(wizard)
          return unless define_step_attributes_methods?

          step_definitions = wizard.steps_processor.step_definitions
          generated_methods = []

          step_definitions.each do |node|
            step_id = node.id
            step_class = node.klass
            next unless step_class.respond_to?(:attribute_names)

            step_class.attribute_names.each do |attr_name|
              attr_sym = attr_name.to_sym

              if respond_to?(attr_sym)
                log_attribute_skipped(step_id, attr_sym)
                next
              end

              define_singleton_method(attr_sym) do
                read.dig(:steps, step_id, attr_sym)
              end

              generated_methods << attr_sym
            end
          end

          log_attributes_defined(wizard, generated_methods)
        end

        # Whether to auto-generate step attribute methods
        #
        # Can be overridden in subclasses to disable auto-generation
        # if custom method definitions are preferred.
        #
        # @return [Boolean] true to enable auto-generation, false to disable
        #
        # @example Disable for specific state store
        #   class CustomStateStore
        #     include DfE::Wizard::StateStore
        #
        #     def define_step_attributes_methods?
        #       false
        #     end
        #   end
        #
        # @api public
        def define_step_attributes_methods?
          true
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

        private

        # Logs when an attribute is skipped during generation
        #
        # @param step_id [Symbol] The step identifier
        # @param attr_name [Symbol] The attribute name
        # @return [void]
        # @api private
        def log_attribute_skipped(step_id, attr_name)
          return unless respond_to?(:logger) && logger.respond_to?(:debug)

          logger.debug(
            "[StateStore] Skipped attribute :#{attr_name} for step :#{step_id} " \
            '(method already exists)',
            category: :state,
          )
        end

        # Logs summary of generated attributes with method names
        #
        # @param wizard [DfE::Wizard] The wizard instance
        # @param methods [Array<Symbol>] List of generated method names
        # @return [void]
        # @api private
        def log_attributes_defined(wizard, methods)
          return unless respond_to?(:logger) && logger.respond_to?(:info)

          logger.info(
            "[StateStore] Auto-generated #{methods.size} attribute reader methods " \
            "for #{wizard.class.name}: #{methods.inspect}",
            category: :state,
          )
        end
      end
    end
  end
end
