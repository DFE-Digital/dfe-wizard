# frozen_string_literal: true

module DfE
  module Wizard
    class Base
      attr_reader :current_step_name, :steps
      attr_accessor :edit, :state_store

      delegate :info, to: :logger, allow_nil: true

      def initialize(current_step: nil, **args)
        @current_step_name = current_step.to_sym if current_step

        # @deprecated
        @steps = self.class.steps

        (args || {}).each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
      end

      # === Step Lookup ===

      def find_step(step_name)
        if steps_processor.respond_to?(:nodes)
          steps_processor.nodes[step_name]&.klass
        else
          warn_deprecation('steps')
          Array(steps).find { |s| s.key?(step_name) }&.fetch(step_name)
        end
      end

      def step_object_class
        find_step(current_step_name)
      end

      def current_step_instance
        @current_step_instance ||= begin
          klass = step_object_class
          params = fetch_step_attributes
          klass.new(params.merge(wizard: self))
        end
      end

      def current_step
        current_step_instance
      end

      def fetch_step_attributes
        if state_store.present?
          state_store.read.dig(:steps, current_step_name) || {}
        else
          warn_deprecation('step_params (use state_store instead)')
          current_step_params
        end
      end

      # === Navigation ===

      def next_step
        if steps_processor
          steps_processor.next_step(current_step_name, data)
        else
          warn_deprecation('step.next_step (define #steps_processor)')
          current_step.next_step
        end
      end

      def previous_step
        if steps_processor
          steps_processor.previous_step(current_step_name, data)
        else
          warn_deprecation('step.previous_step (define #steps_processor)')
          current_step.previous_step
        end
      end

      def path_traversal(target_step = nil, data = nil)
        return steps_processor.path_traversal(target_step, data) if steps_processor

        warn_deprecation('path_traversal (requires #steps_processor)')
        []
      end

      # === Routing ===

      def next_step_path
        resolve_step_path(next_step)
      end

      def previous_step_path(fallback: nil)
        step = previous_step
        return fallback if step.nil? || step == :first_step

        resolve_step_path(step)
      end

      def resolve_step_path(step)
        raise MissingStepError, "Step path cannot be resolved: #{step.inspect}" unless step

        if route_strategy
          route_strategy.resolve(step: step, data: data)
        else
          warn_deprecation('route helpers (use route_strategy instead)')
          '#'
        end
      end

      # === State Handling ===

      def data
        state_store.read
      end

      def save
        if store.present?
          warn_deprecation('store (use state_store instead')
          store.save
        end

        step_data = current_step.serializable_data
        state_store.write(current_step_name => step_data)
      end

      def valid_step?
        current_step.valid?
      end

      def invalid_step?
        !valid_step?
      end

      def to_doc
        steps_processor.to_doc
      end

      # === Hooks for Subclasses ===

      # override these
      def steps_processor; end
      def route_strategy; end
      def logger; end

      # === Deprecated methods ===

      def self.steps
        warn_deprecation('::steps is deprecated (define #steps_processor instead.)')
        return @steps unless block_given?

        @steps = yield
      end

      def self.store(service = nil)
        warn_deprecation('::store is deprecated (use #state_store instead)')
        @store = service if service
        @store
      end

      def store
        warn_deprecation('#store is deprecated (use #state_store)')
        self.class.store&.new(self)
      end

      def update
        warn_deprecation('update (use state_store.write manually)')
        store&.update
      end

      def edit?
        warn_deprecation('#edit? (use route_strategy)')

        @edit.present?
      end

      def url_helpers
        warn_deprecation('#url_helpers (use route_strategy)')

        @url_helpers ||= Rails.application.routes.url_helpers
      end

      def current_step_path(args = nil)
        warn_deprecation('#current_step_path (use route_strategy.resolve)')
        url_helpers.public_send("#{current_step.class.route_name}_path", args)
      end

      def step_params
        warn_deprecation('#step_params (use #state_store)')

        @step_params || ActionController::Parameters.new
      end

      def current_step_params
        warn_deprecation('#step_params (use #state_store)')
        if @step_params && @step_params[current_step_name].present?
          @step_params.require(current_step_name).permit(permitted_params)
        else
          {}
        end
      end

      def permitted_params
        warn_deprecation('permitted_params (use serializable_data instead)')
        step_object_class.try(:permitted_params) || []
      end

      def warn_deprecation(message)
        ActiveSupport.deprecator.warn("[Wizard::Base] #{message}")
      end

      def self.warn_deprecation(message)
        ActiveSupport.deprecator.warn("[Wizard::Base] #{message}")
      end
    end
  end
end
