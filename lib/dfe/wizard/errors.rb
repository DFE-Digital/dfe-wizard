module DfE
  module Wizard
    # Included by every error that dfe-wizard raises on purpose.
    #
    # A module, not a class, so each error can also keep a standard Ruby
    # superclass. InvalidGraph is an ArgumentError, so existing
    # `rescue ArgumentError` code still catches it.
    #
    # @example Rescue any dfe-wizard error
    #   begin
    #     wizard.steps_processor
    #   rescue DfE::Wizard::Error => e
    #     Rails.logger.error(e.message)
    #   end
    #
    # @api public
    module Error; end

    # Raised when a graph breaks a sub-wizard rule. Raised while the graph is
    # drawn, so a broken graph fails on the first request and in specs.
    #
    # @api public
    class InvalidGraph < ArgumentError
      include Error
    end
  end
end
