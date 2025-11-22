module DfE
  module Wizard
    module Core
      module StateStore
        # Reference to the wizard instance that uses this state store.
        # Set during wizard initialization via {#define_step_attributes_methods}.
        #
        # @return [DfE::Wizard, nil] the wizard instance, or nil if not yet initialized
        attr_accessor :wizard

        # The repository instance used for persistent storage.
        #
        # @return [DfE::Wizard::Repository::Base] the repository handling data persistence
        attr_reader :repository

        # Initializes a new state store with the given repository.
        #
        # @param repository [DfE::Wizard::Repository::Base] the repository to use for data storage
        # @return [void]
        #
        # @example Initialize with session repository
        #   repository = DfE::Wizard::Repository::Session.new(session)
        #   state_store = StateStores::PersonalInformation.new(repository: repository)
        def initialize(repository: ::DfE::Wizard::Repository::InMemory.new)
          @repository = repository
          @wizard = nil
        end

        # Generates attribute reader methods for all step attributes and stores wizard reference.
        #
        # This method is automatically called by the wizard during initialization (via `after_initialize`).
        # It dynamically creates reader methods for each attribute defined in the wizard's steps,
        # allowing natural attribute access like `state_store.first_name` instead of
        # `state_store.read[:first_name]`.
        #
        # Skips method generation if:
        # - {#define_step_attributes_methods?} returns false
        # - A method with the same name already exists (preserves custom methods)
        #
        # @param wizard [DfE::Wizard] the wizard instance to generate methods for
        # @return [void]
        #
        # @example Generated methods
        #   # Given a step with attributes :first_name, :last_name
        #   state_store.first_name  # => "John"
        #   state_store.last_name   # => "Doe"
        #
        # @example Custom methods are preserved
        #   class MyStateStore
        #     include DfE::Wizard::Core::StateStore
        #
        #     def full_name
        #       "#{first_name} #{last_name}"  # Custom method not overwritten
        #     end
        #   end
        #
        # @see #define_step_attributes_methods?
        def define_step_attributes_methods(wizard)
          @wizard = wizard
          return unless define_step_attributes_methods?

          generated_methods = []
          skipped_methods = []

          wizard.steps_processor.step_definitions.each do |step|
            step_class = step.klass
            next unless step_class.respond_to?(:attribute_names)

            step_class.attribute_names.each do |attribute_name|
              attribute_sym = attribute_name.to_sym

              # Skip if method already exists (preserve custom methods)
              if respond_to?(attribute_sym, true)
                log_attribute_skipped(step.id, attribute_sym)
                skipped_methods << { attribute: attribute_sym, step: step.id }
                next
              end

              # Define reader method that reads from flat repository data
              define_singleton_method(attribute_sym) do
                read[attribute_sym]
              end

              generated_methods << attribute_sym
            end
          end

          log_attributes_defined(wizard, generated_methods)

          { generated_methods:, skipped_methods: }
        end

        # Controls whether attribute reader methods should be auto-generated.
        #
        # Override this method in your state store class to disable automatic
        # attribute method generation. When disabled, you must manually access
        # attributes via `read[:attribute_name]`.
        #
        # @return [Boolean] true to enable auto-generation (default), false to disable
        #
        # @example Disable auto-generation
        #   class MyStateStore
        #     include DfE::Wizard::Core::StateStore
        #
        #     def define_step_attributes_methods?
        #       false  # Disable automatic method generation
        #     end
        #   end
        #
        # @see #define_step_attributes_methods
        def define_step_attributes_methods?
          true
        end

        # Logs a debug message when an attribute method is skipped.
        #
        # This occurs when an attribute name would collide with an existing method
        # on the state store, and the existing method is preserved.
        #
        # @param step_id [Symbol] the ID of the step containing the attribute
        # @param attr_name [Symbol] the name of the attribute that was skipped
        # @return [void]
        #
        # @example
        #   log_attribute_skipped(:personal_details, :first_name)
        #   # Logs: "[StateStore] Skipped attribute :first_name for step :personal_details (method already exists)"
        #
        # @see #define_step_attributes_methods
        def log_attribute_skipped(step_id, attr_name)
          wizard.log.debug(
            "[StateStore] Skipped attribute :#{attr_name} for step :#{step_id} " \
            '(method already exists)',
            category: :state,
          )
        end

        # Logs an info message summarizing the auto-generated attribute reader methods.
        #
        # Called after all attribute methods have been generated for the state store.
        # Provides insight into which methods were created during initialization.
        #
        # @param wizard [DfE::Wizard] the wizard instance
        # @param generated_methods [Array<Symbol>] list of method names that were generated
        # @return [void]
        #
        # @example
        #   log_attributes_defined(wizard, [:first_name, :last_name, :email])
        #   # Logs: "[StateStore] Auto-generated 3 attribute reader methods for PersonalInfoWizard:
        #   #        [:first_name, :last_name, :email]"
        #
        # @see #define_step_attributes_methods
        def log_attributes_defined(wizard, generated_methods)
          wizard.log.info(
            "[StateStore] Auto-generated #{generated_methods.size} attribute reader methods " \
            "for #{wizard.class.name}: #{generated_methods.inspect}",
            category: :state,
          )
        end

        # @!method read
        #   Reads the current state from the repository.
        #
        #   This method is delegated directly to the repository. In Solution 3 architecture,
        #   the repository stores data as a flat hash of attributes. The wizard is responsible
        #   for transforming this flat hash into the nested `{ steps: {...} }` structure when needed.
        #
        #   @return [Hash] flat hash of all wizard attributes
        #
        #   @example
        #     state_store.read
        #     # => { first_name: "John", last_name: "Doe", email: "john@example.com" }
        #
        #   @note The state store does NOT transform data. It returns the flat hash as-is from
        #     the repository. Transformation to `{ steps: {...} }` happens in the wizard layer.
        #
        #   @see DfE::Wizard::Repository::Base#read

        # @!method write(flat_hash)
        #   Writes state to the repository.
        #
        #   This method is delegated directly to the repository. In Solution 3 architecture,
        #   the wizard is responsible for flattening the `{ steps: {...} }` structure into
        #   a flat hash before calling this method.
        #
        #   @param flat_hash [Hash] flat hash of attributes to store
        #   @return [void]
        #
        #   @example
        #     state_store.write({ first_name: "John", last_name: "Doe" })
        #
        #   @note The state store does NOT transform data. It expects a flat hash and stores
        #     it as-is. Flattening from `{ steps: {...} }` happens in the wizard layer.
        #
        #   @see DfE::Wizard::Repository::Base#write

        # @!method clear
        #   Clears all state from the repository.
        #
        #   This method is delegated directly to the repository. It removes all stored data,
        #   effectively resetting the wizard to a clean state.
        #
        #   @return [void]
        #
        #   @example
        #     state_store.clear
        #     state_store.read  # => {}
        #
        #   @see DfE::Wizard::Repository::Base#clear

        # Pure delegation to repository
        delegate :read, :write, :clear, to: :repository
      end
    end
  end
end
