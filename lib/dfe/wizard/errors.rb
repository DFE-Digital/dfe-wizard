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

    # Raised by `start_edit` when the unit has no step on the path for the
    # record's answers, so the edit has nothing to show.
    #
    # @api public
    class NotCallable < StandardError
      include Error
    end

    # Raised when the changeset does not match the request: an edit
    # changeset under a request built without `record:`, a draft changeset
    # under one built with it, or an edit of another record.
    #
    # @api public
    class ChangesetMismatch < StandardError
      include Error
    end

    # Raised when a request built with `record:` finds no edit changeset:
    # it expired, it was discarded by the commit, or it was never seeded.
    #
    # @api public
    class ChangesetExpired < StandardError
      include Error
    end

    # Raised by `save_current_step` in an edit for a step that the edit does
    # not show.
    #
    # @api public
    class StepNotAccessible < StandardError
      include Error
    end
  end
end
