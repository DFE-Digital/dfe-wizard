# frozen_string_literal: true

module DfE
  module Wizard
    class Logger
      attr_reader :logger, :options

      def initialize(logger, options = {})
        @logger = logger
        @options = options
      end

      def info(message)
        return if options[:if].is_a?(Proc) && options[:if].call.blank?

        @logger.info(
          "#{ActiveSupport::LogSubscriber.new.send(:color, 'DfE::Wizard', :yellow)} #{message}",
        )
      end
    end
  end
end
