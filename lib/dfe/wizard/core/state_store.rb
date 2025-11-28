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
        attr_accessor :attribute_names

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
        # Can be overridden in subclasses to disable method_missing-based
        # attribute access.
        #
        # Useful for strict programming or when attributes should
        # be accessed through explicit methods only.
        #
        # @return [Boolean] true if method_missing should route attributes
        # dynamically
        #
        # @example Disable attribute generation in subclass
        #   class CustomStateStore
        #     include DfE::Wizard::Core::StateStore
        #
        #     def step_attributes_methods?
        #       false  # Disable method_missing
        #     end
        #   end
        #
        # @api public
        def step_attributes_methods?
          true
        end

        # Route unknown method calls to repository data
        #
        # Implements dynamic attribute access for all step attributes.
        # When a method is called that matches an attribute name,
        # this method returns the corresponding value from repository data.
        #
        # This replaces the need to pre-generate singleton methods for
        # every possible attribute. Instead, methods are resolved on-demand
        # through method_missing.
        #
        # ## Call Flow
        #
        # 1. User calls `state_store.first_name`
        # 2. Ruby looks for `first_name` method (not found)
        # 3. Ruby calls `method_missing(:first_name)`
        # 4. Check if `:first_name` in `attribute_names`
        # 5. If yes, return `read[:first_name]`
        # 6. If no, call `super` (raise NoMethodError)
        #
        # ## Performance
        #
        # First call: method_missing overhead (~2-3x slower than direct method)
        # Subsequent calls: same as first (method_missing lookup every time)
        #
        # For typical wizards with 5-10 attributes accessed per request,
        # the performance impact is negligible.
        #
        # @param method_name [Symbol] Name of missing method
        # @param args [Array] Arguments passed to method
        #
        # @return [Object] Value from repository data for the attribute
        #
        # @raise [NoMethodError] If method name is not a known attribute
        #
        # @example Accessing attributes
        #   state_store.attribute_names = [:first_name, :email, :nationality]
        #   state_store.read = { first_name: "Sarah", email: "sarah@example.com" }
        #
        #   state_store.first_name       # => "Sarah"
        #   state_store.email            # => "sarah@example.com"
        #   state_store.nationality      # => nil (not in repository)
        #   state_store.undefined_attr   # => raises NoMethodError
        #
        # @example Custom methods are not affected
        #   class StateStore
        #     include DfE::Wizard::Core::StateStore
        #
        #     def full_name
        #       "#{first_name} #{last_name}"  # Custom implementation
        #     end
        #   end
        #
        #   # full_name is called directly, NOT through method_missing
        #   state_store.full_name  # => Custom logic executed
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
