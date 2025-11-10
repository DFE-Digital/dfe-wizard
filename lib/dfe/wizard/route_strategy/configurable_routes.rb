# frozen_string_literal: true

module DfE
  module Wizard
    module RouteStrategy
      # Configurable route strategy with DSL
      #
      # Allows declarative routing configuration via blocks/lambdas.
      # Use when a wizard has many custom routes or complex routing logic.
      #
      # Falls back to {NamedRoutes} default for unmapped steps.
      #
      # @api public
      #
      # @example Basic usage
      #   strategy = ConfigurableRoutes.new(namespace: 'personal-info') do |config|
      #     config.map_step :email, to: ->(wizard, options, h) {
      #       h.user_email_path(wizard.step(:user).id), options)
      #     }
      #     config.map_step :payment, to: ->(wizard, options, h) {
      #       h.payment_path(wizard.step(:order).id), options)
      #     }
      #   end
      #
      # @example Using helper methods
      #   class MyWizard
      #     include DfE::Wizard
      #
      #     def route_strategy
      #       @route_strategy ||= ConfigurableRoutes.new(namespace: 'app') do |config|
      #         config.map_step :email, to: method(:email_route)
      #         config.map_step :payment, to: method(:payment_route)
      #       end
      #     end
      #
      #     private
      #
      #     def email_route(wizard, options, url_helpers)
      #       user_id = wizard.step(:user).id
      #
      #       url_helpers.user_email_path(user_id, options)
      #     end
      #
      #     def payment_route(wizard, options, url_helpers)
      #       order_id = wizard.step(:order).id)
      #
      #       url_helpers.payment_path(order_id, options)
      #     end
      #   end
      class ConfigurableRoutes < NamedRoutes
        # Initialize with namespace and optional configuration block
        #
        # @param namespace [String, Symbol] The namespace for default routes
        # @param block [Proc] Optional block to configure routes
        #
        # @example
        #   strategy = ConfigurableRoutes.new(wizard: self, namespace: 'app') do |config|
        #     config.map_step :email, to: ->(opts, h) { ... }
        #   end
        #
        # @api public
        def initialize(namespace:, wizard:, &)
          super(namespace:, wizard:)
          @routes = {}
          configure(&) if block_given?
        end

        # Configure routes via block
        #
        # Called during initialization but can also be called later
        # to add more routes.
        #
        # @param block [Proc] Block yielding self for configuration
        # @return [self]
        #
        # @example
        #   strategy = ConfigurableRoutes.new(namespace: 'app')
        #   strategy.configure do |config|
        #     config.map_step :email, to: ->(opts, h) { ... }
        #   end
        #
        # @api public
        def configure
          yield(self) if block_given?
          self
        end

        # Map a step to a routing callable
        #
        # The callable can be:
        # - A lambda: `{ |wizard, options, url_helpers| ... }`
        # - A method: `method(:my_route_method)`
        # - Any object responding to `call(wizard, options, url_helpers)`
        #
        # @param step [Symbol] The step identifier
        # @param to [Proc, Object] The callable that generates the route
        # @return [self]
        #
        # @example With lambda
        #   config.map_step :email, to: ->(wizard, options, h) {
        #     h.user_email_path(wizard.step(:user).id), options)
        #   }
        #
        # @example With method
        #   config.map_step :email, to: method(:email_route)
        #
        # @example With custom object
        #   config.map_step :email, to: EmailRouteResolver.new(wizard)
        #
        # @api public
        def map_step(step, to:)
          @routes[step.to_sym] = to
          self
        end

        # Resolve a step to a URL path
        #
        # Looks up the step in configured routes. If not found, falls back
        # to parent {NamedRoutes} default behavior.
        #
        # @param step [Symbol] The step identifier
        # @param options [Hash] Additional URL options
        # @return [String] The generated URL path
        #
        # @example
        #   strategy.resolve(step: :email, options: {})
        #   # Uses mapped route if configured, otherwise default naming
        #
        # @api public
        def resolve(step:, options: {})
          callable = @routes[step.to_sym]
          return super unless callable

          # Call the routing lambda/method with url helpers
          callable.call(wizard, options, url_helpers)
        end

        # Get all configured routes
        #
        # @return [Hash<Symbol, Proc>]
        #
        # @api public
        def routes
          @routes.dup
        end

        # Check if a step has a configured route
        #
        # @param step [Symbol]
        # @return [Boolean]
        #
        # @api public
        def route?(step)
          @routes.key?(step.to_sym)
        end

        # Clear all configured routes
        #
        # @return [void]
        #
        # @api public
        def clear_routes
          @routes.clear
        end
      end
    end
  end
end
