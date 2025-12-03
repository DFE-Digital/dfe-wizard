module DfE
  module Wizard
    module Tooling
      # Logging support for wizard operations
      #
      # Provides structured logging with automatic sensitive data filtering
      # and category-based exclusions.
      #
      # @api public
      module LogManagement
        # Get logger instance
        #
        # Returns NullLogger if logger method returns nil.
        # Override this method in your wizard to enable logging.
        #
        # @return [Logger, NullLogger]
        #
        # @example Basic logger
        #   def logger
        #     DfE::Wizard::Logging::Logger.new(Rails.logger)
        #   end
        #
        # @example With exclusions
        #   def logger
        #     DfE::Wizard::Logging::Logger.new(Rails.logger)
        #       .exclude(:navigation)
        #       .exclude(:routing)
        #   end
        def logger
          nil # Override in wizard class
        end

        # Get tagged logger instance
        #
        # Internal method that wraps logger with wizard class name tag.
        #
        # @return [TaggedLogger, NullLogger]
        # @api public
        def log
          @log ||= begin
            logger_instance = logger
            logger_instance ? logger_instance.tagged(self.class.name) : DfE::Wizard::NullLogger.new
          end
        end

        # Log next step transition
        #
        # @param from [Symbol] Source step
        # @param to [Symbol] Destination step
        # @api public
        def log_next_step_transition(from:, to:)
          log.info('Next step transition', category: :navigation, from:, to:)
        end

        # Log previous step
        #
        # @param current [Symbol] Current step
        # @param previous [Symbol] Previous step
        # @api public
        def log_previous_step_transition(current:, previous:)
          log.info('Previous step', category: :navigation, previous:, current:)
        end

        # Log path traversal calculation
        #
        # @param target [Symbol] Target step
        # @param path [Array] Calculated path
        # @api public
        def log_flow_path_resolved(target:, path:)
          log.debug('Flow Path', category: :navigation, target:, path:)
        end

        # Log state read operation
        #
        # @param data [Hash] State data read
        # @api public
        def log_state_read(data:)
          steps = data[:steps]&.keys || []
          log.info('State read', category: :state, steps:)
          log.debug('State data', category: :state, data: sanitize_data(data))
        end

        # Log filtered state read operation
        #
        # @param data [Hash] Filtered state data
        # @api public
        def log_filtered_data(data:)
          log.debug('Filtered data', category: :state, data: sanitize_data(data))
        end

        # Log wizard completion
        #
        # @param completed_at [Time] Completion timestamp
        # @api public
        def log_completion(completed_at:)
          log.info('Wizard marked completed', category: :state, completed_at: completed_at)
        end

        # Log state clearing
        #
        # @api public
        def log_clear_state
          log.info('State cleared', category: :state)
        end

        # Log state write operation
        #
        # @param updates [Hash] State updates
        # @api public
        def log_state_write(updates:)
          steps = updates[:steps]&.keys || []
          log.info('State write', category: :state, steps:)
          log.debug('State updates', category: :state, data: sanitize_data(updates))
        end

        # Log step hydration
        #
        # @param step_id [Symbol] Step being hydrated
        # @param attributes [Hash] Step attributes
        # @api public
        def log_step_hydration(step_id:, attributes:)
          log.info('Step hydrated', category: :state, step: step_id, fields: attributes.keys)
          log.debug('Step data', category: :state, step: step_id, data: sanitize_data(attributes))
        end

        # Logs parameter extraction errors
        #
        # Called when parameter extraction fails due to missing required parameters
        # or unimplemented permitted_params method.
        #
        # @param step_id [Symbol] The step identifier where error occurred
        # @param error [String] Error class name
        #
        # @return [void]
        #
        # @api private
        def log_params_error(step_id:, error:)
          return unless logger.respond_to?(:warn)

          logger.info(
            "Parameter extraction failed for step :#{step_id}: #{error}",
            category: :state,
          )
        end

        # Log validation result
        #
        # @param type [Symbol] Validation type
        # @param result [Boolean] Validation passed?
        # @param details [Hash] Additional context
        # @api public
        def log_validation(type:, result:, **details)
          log.info('Validation', category: :validation, type:, result:, **details)

          if !result && details[:errors]
            log.info('Validation errors', category: :validation, errors: details[:errors])
          end
        end

        # Log callback execution
        #
        # @param name [Symbol] Callback name
        # @param result [Object] Callback return value
        # @api public
        def log_callback(name:, result:)
          log.info('Callback executed', category: :callbacks, name:, returned: result.class.name)
          log.debug('Callback result', category: :callbacks, name:, result: result.inspect)
        end

        # Log conditional branch evaluation
        #
        # @param from [Symbol] Source step
        # @param condition [String] Condition label
        # @param result [Boolean] Evaluation result
        # @param chosen [Symbol] Chosen branch
        # @api public
        def log_conditional(from:, condition:, result:, chosen:)
          log.info(
            'Conditional branch',
            category: :navigation,
            from:,
            condition:,
            result:,
            chosen:,
          )
        end

        # Log step save operation
        #
        # @param step_id [Symbol] Step being saved
        # @param data [Hash] Data being saved
        # @api public
        def log_step_save(step_id:, data:)
          log.info('Step saved', category: :state, step: step_id, fields: data.keys)
          log.debug('Saved data', category: :state, step: step_id, data: sanitize_data(data))
        end

        # Log route resolution
        #
        # @param step [Symbol] Step identifier
        # @param path [String] Resolved path
        # @api public
        def log_route_resolved(step:, path:)
          log.debug('Route resolved', category: :routing, step:, path:)
        end

        # Logs parameter extraction details for debugging wizard state changes
        #
        # Called when parameters are received for a step, logging both raw and
        # permitted parameters to help debug form submission and state persistence.
        #
        # @param step_id [Symbol] The step identifier receiving parameters
        # @param raw_params [Hash] Unfiltered parameters from controller/request
        # @param permitted_params [Hash] Filtered parameters after Strong Parameters
        #
        # @return [void]
        #
        # @example Logging during parameter extraction
        #   log_params_received(
        #     step_id: :qualification_type,
        #     raw_params: { qualification_type: { has_qualification: 'yes', extra: 'filtered' } },
        #     permitted_params: { has_qualification: 'yes' }
        #   )
        #   # => "[StepManagement] Params received for step :qualification_type:
        #   #     raw_count: 2, permitted_count: 1, filtered: 1,
        #   #     permitted_keys: [:has_qualification]"
        #
        # @note Only logs when logger responds to :debug (no-op for NullLogger)
        # @note Calculates filtered count to highlight parameter security filtering
        #
        # @api private
        def log_params_received(step_id:, raw_params:, permitted_params:)
          log.debug(
            'Params data',
            category: :state,
            step: step_id,
            raw: sanitize_data(raw_params.to_h),
            permitted: sanitize_data(permitted_params.to_h),
          )
        end

        # Sanitize data using Rails parameter filter
        #
        # @param data [Hash] Data to sanitize
        # @return [Hash] Sanitized data
        # @api public
        def sanitize_data(data)
          return data unless defined?(Rails)

          parameter_filter.filter(data)
        end

        # Get Rails parameter filter instance
        #
        # @return [ActiveSupport::ParameterFilter]
        # @api public
        def parameter_filter
          @parameter_filter ||= ActiveSupport::ParameterFilter.new(
            Rails.application.config.filter_parameters,
          )
        end
      end
    end
  end
end
