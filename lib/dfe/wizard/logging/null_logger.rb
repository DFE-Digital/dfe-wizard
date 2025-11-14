module DfE
  module Wizard
    module Logging
      # Null logger (no-op)
      #
      # Used when logging is disabled.
      # Responds to all logger methods but does nothing.
      #
      # @api public
      class NullLogger
        def tagged(*)
          self
        end

        def info(*); end
        def debug(*); end
        def warn(*); end
        def error(*); end

        def exclude(*)
          self
        end

        def reset_exclusions
          self
        end

        def excluded?(_category)
          false
        end

        def excluded_categories
          []
        end
      end
    end
  end
end
