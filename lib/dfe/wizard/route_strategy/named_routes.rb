module DfE
  module Wizard
    module RouteStrategy
      class NamedRoutes
        def initialize(namespace:)
          @namespace = namespace.to_s.underscore
        end

        def resolve(step:, data:)
          route_name = [@namespace, step].compact.join('_')

          url_helpers.public_send("#{route_name}_path")
        end

        def url_helpers
          Rails.application.routes.url_helpers
        end
      end
    end
  end
end
