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
      class ConfigurableRoutes < NamedRoutes
        # Initialize with namespace and optional configuration block
        #
        # @param namespace [String, Symbol] The namespace for default routes
        # @param wizard [DfE::Wizard] The wizard instance
        # @param block [Proc] Optional block to configure routes
        #
        # @example
        #   strategy = ConfigurableRoutes.new(wizard: self, namespace: 'app') do |config|
        #     config.default_path_arguments = { provider_id: 123 }
        #     config.map_step :email, to: ->(wizard, opts, h) { ... }
        #   end
        #
        # @api public
        def initialize(namespace:, wizard:, &)
          super(namespace: namespace, wizard: wizard)
          @routes = {}
          @default_path_arguments = {}
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
        # @api public
        def configure
          yield(self) if block_given?
          self
        end

        # Set default path arguments for all routes
        #
        # These arguments are merged with step-specific options when
        # generating URLs. Useful for wizards that need consistent
        # parameters like provider_code, course_code, etc.
        #
        # @param args [Hash] Default arguments
        # @return [Hash] The set default arguments
        #
        # @example
        #   config.default_path_arguments = {
        #     provider_code: 'ABC',
        #     recruitment_cycle_year: 2024
        #   }
        #
        # @api public
        attr_writer :default_path_arguments

        # Get default path arguments
        #
        # @return [Hash]
        #
        # @api public
        def default_path_arguments
          @default_path_arguments || {}
        end

        # Map a step to a routing callable
        #
        # The callable receives:
        # - wizard: The wizard instance
        # - options: Merged default_path_arguments + step options
        # - url_helpers: Rails URL helper methods
        #
        # @param step [Symbol] The step identifier
        # @param to [Proc, Object] The callable that generates the route
        # @return [self]
        #
        # @example With lambda
        #   config.map_step :email, to: ->(wizard, options, h) {
        #     h.user_email_path(wizard.step(:user).id, **options)
        #   }
        #
        # @example With method
        #   config.map_step :email, to: method(:email_route)
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
        # Merges default_path_arguments with step-specific options.
        #
        # @param step [Symbol] The step identifier
        # @param options [Hash] Additional URL options
        # @return [String] The generated URL path
        #
        # @example
        #   strategy.resolve(step_id: :email, options: { user_id: 5 })
        #   # Merges { provider_code: 'ABC' } + { user_id: 5 }
        #
        # @api public
        def resolve(step_id:, options: {})
          callable = @routes[step_id.to_sym]

          # Merge default path arguments with step options
          merged_options = default_path_arguments.merge(options)

          if callable
            # Call the routing lambda/method with merged options
            callable.call(wizard, merged_options, url_helpers)
          else
            # Fall back to NamedRoutes with merged options
            super(step_id:, options: merged_options)
          end
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
