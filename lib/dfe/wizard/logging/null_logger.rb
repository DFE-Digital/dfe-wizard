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
        def tagged(*) = self
        def info(*); end
        def debug(*); end
        def warn(*); end
        def error(*); end
      end
    end
  end
end
