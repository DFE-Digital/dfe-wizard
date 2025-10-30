# frozen_string_literal: true

module DfE
  module Wizard
    # The Wizard::Base acts as the orchestrator between a multi-step form system and a backing
    # data store. It supports both old-style `step_params`-based interfaces and the newer
    # graph-based systems using `steps_processor` and `state_store`.
    #
    # ## Implementation
    #
    # Subclass this base and implement:
    #
    # - `#steps_processor` → returns a steps processor (e.g., instance of `Graph`)
    # - `#state_store` → provides `read`/`write` for wizard data
    # - `#route_strategy` → (optional) an object that responds to `resolve(step:, data:)`
    #
    # Example:
    #
    #   class MyWizard < DfE::Wizard::Base
    #     def steps_processor
    #       DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
    #         graph.add_node :step_one, StepClasses::One
    #         graph.root :step_one
    #         ...
    #       end
    #     end
    #
    #     def state_store
    #       StateStores::WizardStore.new(my_model_instance)
    #     end
    #   end
    #
    class Base
      attr_reader :current_step_name, :steps
      attr_accessor :edit, :state_store, :step_params

      delegate :info, to: :logger, allow_nil: true

      # Initializes a new wizard instance.
      #
      # @param current_step [Symbol, nil] The name of the current step
      # @param args [Hash] Additional dependencies
      # @option args [Object] :state_store custom object that responds to `read` + `write`
      # @option args [Boolean] :edit whether this is an editable wizard
      def initialize(current_step: nil, **args)
        @current_step_name = current_step.to_sym if current_step

        # For back compatibility with steps() DSL
        @steps = self.class.steps

        args.each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
      end

      # === Step Lookup ===

      # Find the class corresponding to a step name.
      # @param step_name [Symbol]
      # @return [Class, nil] the step class
      def find_step(step_name)
        if steps_processor.respond_to?(:find_step)
          steps_processor.find_step(step_name)
        else
          warn_deprecation('steps')
          Array(steps).find { |s| s.key?(step_name) }&.fetch(step_name)
        end
      end

      # The step class for the current step.
      # @return [Class, nil]
      def step_object_class
        find_step(current_step_name)
      end

      # The instantiated step object.
      # @return [Object] the step instance
      def current_step_instance
        @current_step_instance ||= begin
          klass = step_object_class
          params = fetch_step_attributes
          klass.new(params.merge(wizard: self, step_id: current_step_name))
        end
      end

      # Alias for `current_step_instance`.
      def current_step
        current_step_instance
      end

      # Extracts parameters for the current step from the state store (or fallback).
      # @return [Hash] step attributes
      def fetch_step_attributes
        if state_store.present?
          state_data = state_store.read.dig(:steps, current_step_name) || {}
          state_data.deep_stringify_keys.deep_merge(current_step_params.to_h)
        else
          current_step_params.to_h
        end
      end

      # === Navigation ===

      # Returns the next step based on the steps_processor.
      # @return [Symbol]
      def next_step
        if steps_processor
          steps_processor.next_step(current_step_name, data)
        else
          warn_deprecation('step.next_step (define #steps_processor)')
          current_step.next_step
        end
      end

      # Returns the previous step.
      # @return [Symbol]
      def previous_step
        if steps_processor
          steps_processor.previous_step(current_step_name, data)
        else
          warn_deprecation('step.previous_step (define #steps_processor)')
          current_step.previous_step
        end
      end

      # Returns an array of step names representing a possible path to a target step.
      # @param target_step [Symbol, nil]
      # @param data [Hash, optional] override wizard data (default: wizard.data)
      # @return [Array<Symbol>]
      def path_traversal(target_step = nil, data = nil)
        return steps_processor.path_traversal(target_step, data) if steps_processor

        warn_deprecation('path_traversal (requires #steps_processor)')
        []
      end

      # === Routing ===

      # The path helper for the next step.
      # @return [String]
      def next_step_path
        resolve_step_path(next_step)
      end

      # The path helper for the previous step.
      # @param fallback [String, nil] Fallback URL if no previous step
      # @return [String, nil]
      def previous_step_path(fallback: nil)
        step = previous_step
        return fallback if step.nil? || step == :first_step

        resolve_step_path(step)
      end

      # Resolves a URL/path for a given step, via the route strategy.
      # Requires a `route_strategy` object that implements: `resolve(step:, data:)`
      #
      # @param step [Symbol]
      # @return [String]
      def resolve_step_path(step, options = {})
        raise MissingStepError, "Step path cannot be resolved: #{step.inspect}" unless step

        if route_strategy
          route_strategy.resolve(step:, data:, options:)
        else
          warn_deprecation('route helpers (use route_strategy instead)')
          '#'
        end
      end

      # === State Handling ===

      # Reads the current wizard data from state store.
      # @return [Hash]
      def data
        state_store.read
      end

      # Saves the current step data to state_store.
      # WARNING: Also supports the deprecated `store` interface.
      # @return [void]
      def save
        if store.present?
          warn_deprecation('store (use state_store instead')
          store.save
        end

        step_data = current_step.serializable_data
        state_store.write(current_step_name => step_data)
      end

      # Validates the current step.
      # @return [Boolean]
      def valid_step?
        current_step.valid?
      end

      # Inverse of `valid_step?`.
      # @return [Boolean]
      def invalid_step?
        !valid_step?
      end

      # Generates documentation representing the step graph (e.g. Graphviz).
      # @return [GraphViz]
      def to_doc
        steps_processor.to_doc
      end

      # === Hooks for Subclasses ===

      # Provide a custom graph-based steps processor.
      # Expected interface:
      #   - #next_step(step_name, data)
      #   - #previous_step(step_name, data)
      #   - #path_traversal(target_step = nil, data = nil)
      #   - #nodes → Hash{ step_name => StepStruct(id:, klass:) }
      #
      # @return [Object, nil]
      def steps_processor; end

      # Optional: Object implementing a custom strategy for resolving URLs.
      # Required interface:
      #   - #resolve(step:, data:) → String
      #
      # @return [Object, nil]
      def route_strategy; end

      # Allows subclass to customize logger (e.g., ActiveSupport::Logger).
      #
      # @return [Logger, nil]
      def logger; end

      # === Deprecated methods (do NOT use in new projects) ===

      # Legacy step registration DSL.
      def self.steps
        return @steps unless block_given?

        warn_deprecation('::steps is deprecated (define #steps_processor instead.)')

        @steps = yield
      end

      # Legacy store (deprecated: use `state_store`)
      def self.store(service = nil)
        warn_deprecation('::store is deprecated (use #state_store instead)')
        @store = service if service
        @store
      end

      # Legacy instance method for `store`
      def store
        warn_deprecation('#store is deprecated (use #state_store)')
        self.class.store&.new(self)
      end

      # Deprecated update using legacy store
      def update
        warn_deprecation('update (use state_store.write manually)')
        store&.update
      end

      # Deprecated edit tracking
      # Use routers/routing context to manage edit state
      def edit?
        warn_deprecation('#edit? (use route_strategy)')
        @edit.present?
      end

      # Rails URL helpers — deprecated use
      def url_helpers
        warn_deprecation('#url_helpers (define #route_strategy)')
        @url_helpers ||= Rails.application.routes.url_helpers
      end

      def current_step_path(args = nil)
        if route_strategy.present?
          resolve_step_path(current_step_name, args)
        else
          warn_deprecation('Define #route_strategy on wizard class')
          url_helpers.public_send("#{current_step.class.route_name}_path", args)
        end
      end

      def current_step_params
        if @step_params && @step_params[current_step_name].present?
          @step_params.require(current_step_name).permit(permitted_params)
        else
          {}
        end
      end

      def summary_steps
        traversal = path_traversal(:review, data)

        traversal.map do |step_id|
          klass = find_step(step_id)
          step_data = data.dig(:steps, step_id) || {}

          klass.new(step_data.merge(wizard: self, step_id:))
        end
      end

      def permitted_params
        step_object_class.permitted_params
      end

      # Emits a deprecation warning
      # @param message [String]
      def warn_deprecation(message)
        ActiveSupport.deprecator.warn("[Wizard::Base] #{message}")
      end

      def self.warn_deprecation(message)
        ActiveSupport.deprecator.warn("[Wizard::Base] #{message}")
      end
    end
  end
end
