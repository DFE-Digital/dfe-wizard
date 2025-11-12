module DfE
  module Wizard
    module Logging
      # Tagged logger for wizard operations
      #
      # Wraps Rails logger with automatic tagging support.
      # All log messages are prefixed with wizard class name.
      #
      # @example Enable logging in wizard
      #   class MyWizard
      #     include DfE::Wizard
      #
      #     def logger
      #       DfE::Wizard::Logger.new(Rails.logger) if Rails.env.development?
      #     end
      #   end
      #
      # @api public
      class Logger
        def initialize(rails_logger)
          @logger = rails_logger
        end

        # Create tagged logger scope
        #
        # @param tag [String] Tag to prefix all log messages
        # @return [TaggedLogger]
        def tagged(tag)
          TaggedLogger.new(@logger, tag)
        end
      end

      # Tagged logger instance
      #
      # Internal class that handles actual logging with tags
      #
      # @api private
      class TaggedLogger
        def initialize(logger, tag)
          @logger = logger
          @tag = tag
        end

        def info(message, **context)
          log(:info, message, **context)
        end

        def debug(message, **context)
          log(:debug, message, **context)
        end

        def warn(message, **context)
          log(:warn, message, **context)
        end

        def error(message, **context)
          log(:error, message, **context)
        end

        private

        def log(level, message, **context)
          return unless @logger

          context_string = context.map { |k, v| "#{k}=#{format_value(v)}" }.join(' ')
          full_message = context_string.empty? ? message : "#{message} #{context_string}"

          @logger.tagged(@tag) do
            @logger.public_send(level, full_message)
          end
        end

        def format_value(value)
          case value
          when Array
            "[#{value.map(&:inspect).join(', ')}]"
          when Hash
            "{#{value.map { |k, v| "#{k}: #{format_value(v)}" }.join(', ')}}"
          else
            value.inspect
          end
        end
      end
    end
  end
end
