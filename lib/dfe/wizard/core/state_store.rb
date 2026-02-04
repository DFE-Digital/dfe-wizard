module DfE
  module Wizard
    module Core
      module StateStore
        # Reference to the wizard instance that uses this state store.
        # Set during wizard initialization via {#step_attributes_methods}.
        #
        # @return [DfE::Wizard, nil] the wizard instance, or nil if not yet initialized
        attr_accessor :wizard

        # The repository instance used for persistent storage.
        #
        # @return [DfE::Wizard::Repository::Base] the repository handling data persistence
        attr_reader :repository

        # @return [Array<Hash>] Step definitions from wizard
        attr_accessor :step_definitions

        # @return [Array<String, Symbol>] All attribute names from all steps
        attr_reader :attribute_names

        # Sets attribute names and generates explicit accessor methods.
        #
        # Instead of relying on method_missing, this generates real methods
        # for each attribute, making data flow explicit and easier to debug.
        #
        # @param names [Array<String, Symbol>] all steps attribute names
        # @return [void]
        def attribute_names=(names)
          @attribute_names = names
          define_attribute_accessors if step_attributes_methods?
        end

        # Initializes a new state store with the given repository.
        #
        # @param repository [DfE::Wizard::Repository::Base] the repository to use for data storage
        # @param attribute_names [Array] all steps attribute names (uniq)
        # @param step_definitions [Array] All steps from the wizard
        # @return [void]
        #
        # @example Initialize with session repository
        #   repository = DfE::Wizard::Repository::Session.new(session)
        #   state_store = StateStores::PersonalInformation.new(repository: repository)
        def initialize(repository: ::DfE::Wizard::Repository::InMemory.new, attribute_names: [], step_definitions: [])
          @repository = repository
          @attribute_names = attribute_names
          @step_definitions = step_definitions
        end

        # Retrieve value by key
        #
        # @param key [Symbol] Data key
        # @return [Object] Stored value
        def [](key)
          read[key]
        end

        # Execute operation on current context
        #
        # @param operation_class [Class] Operation to run
        # @param step [DfE::Wizard::Step] Step instance
        # @return [Hash] Operation result { success:, errors: }
        def execute_operation(operation_class:, step:)
          @repository.execute_operation(operation_class:, step:)
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

        # Determine if attribute methods generation from steps are enabled
        #
        # Can be overridden in subclasses to disable automatic attribute
        # accessor generation.
        #
        # Useful for strict programming or when attributes should
        # be accessed through explicit methods only.
        #
        # @return [Boolean] true if accessor methods should be generated
        #
        # @example Disable attribute generation in subclass
        #   class CustomStateStore
        #     include DfE::Wizard::Core::StateStore
        #
        #     def step_attributes_methods?
        #       false  # Disable accessor generation
        #     end
        #   end
        #
        # @api public
        def step_attributes_methods?
          true
        end

        # Generate explicit accessor methods for all step attributes.
        #
        # Instead of relying on method_missing, this generates real singleton
        # methods for each attribute. This makes data flow explicit:
        # - state_store.first_name calls a real method, not method_missing
        # - Easier to debug and trace in stack traces
        # - Better IDE support for autocompletion
        #
        # Methods are only generated if they don't already exist on the object,
        # preserving any custom implementations in subclasses.
        #
        # @return [void]
        #
        # @example Generated methods
        #   state_store.attribute_names = [:first_name, :last_name]
        #   # Generates:
        #   #   def first_name; read[:first_name]; end
        #   #   def last_name; read[:last_name]; end
        #
        # @api private
        def define_attribute_accessors
          attribute_names.each do |attr|
            attr_sym = attr.to_sym

            next if respond_to?(attr_sym)

            define_singleton_method(attr_sym) { read[attr_sym] }
          end
        end

        # Fallback for attribute access when explicit methods haven't been generated.
        #
        # With explicit accessor generation (see {#define_attribute_accessors}),
        # this method is rarely called. It exists as a fallback for:
        # - Attributes accessed before attribute_names is set
        # - Edge cases where generation was skipped
        #
        # @param method_name [Symbol] Name of missing method
        # @param args [Array] Arguments passed to method
        #
        # @return [Object] Value from repository data for the attribute
        #
        # @raise [NoMethodError] If method name is not a known attribute
        #
        # @api private
        def method_missing(method_name, *args)
          if step_attribute?(method_name)
            read[method_name]
          else
            super
          end
        end

        # Check if an attribute name is a known step attribute
        #
        # Internal helper method used by both {#method_missing} and {#respond_to_missing?}
        # to determine whether a method call should be routed to repository data.
        #
        # ## Logic
        #
        # Returns true only if:
        # 1. Attribute method generation is enabled via {#step_attributes_methods?}
        # 2. The attribute name exists in the `attribute_names` collection
        #
        # This two-part check allows:
        # - Disabling all dynamic attribute access by overriding `step_attributes_methods?`
        # - Maintaining custom methods that won't be affected by method_missing
        #
        # @param attribute_name [Symbol, String] Name to check
        #
        # @return [Boolean] true if the name is a known step attribute and generation is enabled
        #
        # @example Checking attributes
        #   state_store.attribute_names = [:first_name, :email]
        #   state_store.step_attributes_methods? # => true
        #
        #   state_store.step_attribute?(:first_name)    # => true
        #   state_store.step_attribute?(:email)         # => true
        #   state_store.step_attribute?(:undefined)     # => false
        #
        # @example With generation disabled
        #   state_store.attribute_names = [:first_name, :email]
        #   # Override step_attributes_methods? to return false
        #
        #   state_store.step_attribute?(:first_name)    # => false (generation disabled)
        #   state_store.step_attribute?(:email)         # => false (generation disabled)
        #
        # @note This method is called internally by {#method_missing} and {#respond_to_missing?}
        #   and is rarely called directly by user code.
        #
        # @see #method_missing Which uses this to route attribute access
        # @see #respond_to_missing? Which uses this for introspection
        # @see #step_attributes_methods? Which enables/disables attribute generation
        # @api public
        def step_attribute?(attribute_name)
          step_attributes_methods? && attribute_names.include?(attribute_name.to_s)
        end

        # Support respond_to? for dynamic attributes
        #
        # Enables proper introspection of dynamic attribute methods.
        # When `respond_to?` is called with an attribute name, returns true
        # if that attribute exists in `attribute_names`.
        #
        # This is necessary for Rails/Rack compatibility and proper
        # duck-typing support.
        #
        # @param method_name [Symbol, String] Name to check
        # @param include_private [Boolean] Include private methods (default: false)
        #
        # @return [Boolean] true if method_name is a known attribute or exists
        #
        # @example Checking for attributes
        #   state_store.attribute_names = [:first_name, :email]
        #
        #   state_store.respond_to?(:first_name)   # => true
        #   state_store.respond_to?(:email)        # => true
        #   state_store.respond_to?(:undefined)    # => false
        #
        # @example Works with Rails parameter helpers
        #   # Rails uses respond_to? internally
        #   params.require(:state_store)   # Works with respond_to? support
        #
        # @api public
        def respond_to_missing?(method_name, include_private = false)
          step_attribute?(method_name) || super
        end
      end
    end
  end
end
