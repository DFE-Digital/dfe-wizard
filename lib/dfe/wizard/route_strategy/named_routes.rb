# frozen_string_literal: true

module DfE
  module Wizard
    module RouteStrategy
      # Rails named routes strategy
      #
      # Generates URLs using Rails named route helpers.
      # Routes are built by combining namespace with step ID.
      #
      # Default pattern: `#{namespace}_#{step}_path`
      #
      # Use this when most steps follow the standard naming convention.
      # For wizards with many custom routes, use {ConfigurableRouteStrategy}.
      #
      # @api public
      #
      # @example Standard usage
      #   strategy = NamedRoutes.new(wizard: self, namespace: 'personal-information')
      #   strategy.resolve(step_id: :email, options: {})
      #   # Calls: personal_information_email_path()
      #
      # @example With custom override
      #   class CustomRouteStrategy < NamedRoutes
      #     def resolve(step_id:, options: {})
      #       case step
      #       when :email
      #         url_helpers.user_email_path(wizard.step(:user).id), options)
      #       else
      #         super
      #       end
      #     end
      #   end
      class NamedRoutes
        # Initialize with namespace
        #
        # @param namespace [String, Symbol] The namespace for route names
        #
        # @example
        #   strategy = NamedRoutes.new(wizard: self, namespace: 'personal-information')
        def initialize(namespace:, wizard:)
          @namespace = namespace.to_s.underscore
          @wizard = wizard
        end

        # Resolve a step to a URL path
        #
        # Builds the route name and calls the Rails named route helper.
        #
        # Default pattern:
        # - Namespace: personal_information
        # - Step: email
        # - Route called: personal_information_email_path(options)
        #
        # Can be overridden in subclasses to customize routing for specific steps.
        #
        # @param step [Symbol] The step identifier
        # @param options [Hash] Additional options to pass to route helper
        # @return [String] The generated URL path
        #
        # @example Basic usage
        #   strategy.resolve(step_id: :email, options: {})
        #   # => "/personal-information/email"
        #
        # @example With parameters
        #   strategy.resolve(
        #     step_id: :email,
        #     options: { return_to_review: :review }
        #   )
        #   # => "/personal-information/email?return_to_review=review"
        #
        # @api public
        def resolve(step_id:, options: {})
          route_name = route_name_for(step_id)

          url_helpers.public_send("#{route_name}_path", options)
        end

        # Build route name for a step
        #
        # Combines namespace with step ID.
        # Override this to customize naming convention.
        #
        # @param step [Symbol] The step identifier
        # @return [String] The route name (without _path suffix)
        #
        # @example
        #   strategy.route_name_for(:email)  # => "personal_information_email"
        #
        # @api public
        def route_name_for(step)
          [@namespace, step].compact.join('_')
        end

        # Access Rails URL helpers
        #
        # @return [Module]
        # @raise [RuntimeError] If Rails is not loaded
        #
        # @api private
        def url_helpers
          raise 'Rails is required for NamedRoutes strategy' unless defined?(Rails)

          Rails.application.routes.url_helpers
        end

        # Get the namespace used for route names
        #
        # @return [String]
        #
        # @api public
        attr_reader :namespace

        # Get the wizard
        #
        # @api public
        attr_reader :wizard
      end
    end
  end
end
