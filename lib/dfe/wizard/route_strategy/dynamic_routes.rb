# lib/dfe/wizard/route_strategy/dynamic_routes.rb

module DfE
  module Wizard
    module RouteStrategy
      # Dynamic routes with state key support
      #
      # Use when you need:
      # - Multiple concurrent wizard instances per user
      # - State isolation by unique key
      # - URLs that include state reference
      #
      # State key management:
      # - State key is generated and managed by state store
      # - Route strategy reads it from state store
      # - URLs include state key for isolation
      #
      # Security:
      # - Always verify user owns the state key
      # - Use UUIDs, not sequential IDs
      # - Check ownership in controller before loading wizard
      #
      # @example
      #   strategy = DynamicRoutes.new(
      #     state_store: state_store,
      #     path_builder: ->(step, state_key, options) {
      #       "/some-wizard/#{state_key}/#{step}"
      #     }
      #   )
      #
      # @api public
      class DynamicRoutes
        # Initialize with state store and path builder
        #
        # @param state_store [DfE::Wizard::StateStore::Base] The state store
        # @param path_builder [Proc] Lambda to build URL paths
        #
        # @example Basic usage
        #   DynamicRoutes.new(
        #     state_store: state_store,
        #     path_builder: ->(step, state_key, opts) {
        #       "/some-wizard/#{state_key}/#{step}"
        #     }
        #   )
        #
        # @example With URL helpers
        #   DynamicRoutes.new(
        #     state_store: state_store,
        #     path_builder: ->(step, state_key, opts) {
        #       Rails.application.routes.url_helpers.some_wizard_step_path(
        #         state_key: state_key,
        #         step_id: step,
        #         **opts
        #       )
        #     }
        #   )
        def initialize(state_store:, path_builder:)
          @state_store = state_store
          @path_builder = path_builder
        end

        # Resolve a step to a URL path
        #
        # Includes state key from state store in the URL.
        #
        # @param step [Symbol] The step identifier
        # @param options [Hash] Additional URL options
        # @return [String] The generated URL path with state key
        #
        # @example
        #   strategy.resolve(step_id: :email, options: {})
        #   # => "/wizards/abc-123-def/email"
        def resolve(step_id:, options: {})
          @path_builder.call(step_id, state_key, options)
        end

        # Get state key from state store
        #
        # @return [String, nil]
        # @api public
        def state_key
          @state_store.state_key
        end
      end
    end
  end
end
