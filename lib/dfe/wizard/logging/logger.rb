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
      # @example Enable logging with exclusions
      #   class MyWizard
      #     include DfE::Wizard
      #
      #     def logger
      #       DfE::Wizard::Logger.new(Rails.logger)
      #         .exclude(:navigation)
      #         .exclude(:routing)
      #     end
      #   end
      #
      # @api public
      class Logger
        # Available logging categories
        CATEGORIES = %i[navigation routing state validation callbacks step_processor].freeze

        def initialize(rails_logger)
          @logger = rails_logger
          @excluded = Set.new
        end

        # Exclude one or more logging categories
        #
        # @param categories [Array<Symbol>] Categories to exclude
        # @return [self] Returns self for method chaining
        # @raise [ArgumentError] if unknown category provided
        #
        # @example
        #   logger.exclude(:navigation).exclude(:routing)
        #
        # @api public
        def exclude(*categories)
          categories.each do |category|
            unless CATEGORIES.include?(category)
              raise ArgumentError,
                    "Unknown category: #{category}. Valid categories: #{CATEGORIES.join(', ')}"
            end
          end

          @excluded.merge(categories)

          self
        end

        # Create tagged logger scope
        #
        # @param tag [String] Tag to prefix all log messages
        # @return [TaggedLogger]
        def tagged(tag)
          TaggedLogger.new(@logger, tag, @excluded)
        end

        # Reset all exclusions
        #
        # @return [self]
        # @api public
        def reset_exclusions
          @excluded.clear
          self
        end

        # Check if category is excluded
        #
        # @param category [Symbol] Category to check
        # @return [Boolean]
        # @api public
        def excluded?(category)
          @excluded.include?(category)
        end

        # Get list of excluded categories
        #
        # @return [Array<Symbol>]
        # @api public
        def excluded_categories
          @excluded.to_a
        end
      end

      # Tagged logger instance
      #
      # Internal class that handles actual logging with tags
      #
      # @api private
      class TaggedLogger
        def initialize(logger, tag, excluded)
          @logger = logger
          @tag = tag
          @excluded = excluded
        end

        def info(message, category: nil, **context)
          log(:info, message, category:, **context)
        end

        def debug(message, category: nil, **context)
          log(:debug, message, category:, **context)
        end

        def warn(message, category: nil, **context)
          log(:warn, message, category:, **context)
        end

        def error(message, category: nil, **context)
          log(:error, message, category:, **context)
        end

        private

        def log(level, message, category: nil, **context)
          return unless @logger

          return if category&.in?(@excluded)

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
