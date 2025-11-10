# lib/dfe/wizard/core/logging.rb
# frozen_string_literal: true

module DfE
  module Wizard
    module Core
      # Logging support for wizard operations
      #
      # Provides structured logging with automatic sensitive data filtering.
      # INFO logs show keys only, DEBUG logs show full data (filtered).
      #
      # Uses Rails.application.config.filter_parameters for filtering.
      #
      # @example Enable logging
      #   class MyWizard
      #     include DfE::Wizard
      #
      #     def logger
      #       DfE::Wizard::Logger.new(Rails.logger)
      #     end
      #   end
      #
      #   # Or if you wanna enable only in development and test
      #   class MyWizard
      #     include DfE::Wizard
      #
      #     def logger
      #       DfE::Wizard::Logger.new(Rails.logger) if Rails.env.local?
      #     end
      #   end
      #
      # @example Configure filtered parameters
      #   # config/initializers/filter_parameter_logging.rb
      #   Rails.application.config.filter_parameters += [:password, :ssn]
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
        # @example
        #   def logger
        #     DfE::Wizard::Logger.new(Rails.logger)
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

        # Log step transition
        #
        # Records when user navigates between steps.
        #
        # @param from [Symbol] Source step
        # @param to [Symbol] Destination step
        # @param direction [Symbol] :forward or :backward
        #
        # @example
        #   log_step_transition(from: :name, to: :email, direction: :forward)
        #   # => [MyWizard] Step transition from=:name to=:email direction=:forward
        #
        # @api public
        def log_step_transition(from:, to:, direction:)
          log.info('Step transition', from:, to:, direction:)
        end

        # Log path traversal calculation
        #
        # Records path calculation for navigation.
        #
        # @param target [Symbol] Target step
        # @param path [Array<Symbol>] Calculated path
        #
        # @example
        #   log_path_traversal(target: :review, path: [:name, :email, :review])
        #   # => [MyWizard] Path traversal target=:review path=[:name, :email, :review]
        #
        # @api public
        def log_path_traversal(target:, path:)
          log.debug('Path traversal', target:, path:)
        end

        # Log state read operation
        #
        # Records when state is loaded from store.
        # INFO level shows step names, DEBUG shows full data (filtered).
        #
        # @param data [Hash] State data read
        #
        # @example
        #   log_state_read(data: {steps: {name: {...}, email: {...}}})
        #   # INFO: [MyWizard] State read steps=[:name, :email]
        #   # DEBUG: [MyWizard] State data data={steps: {...}}
        #
        # @api public
        def log_state_read(data:)
          steps = data[:steps]&.keys || []
          log.info('State read', steps:)
          log.debug('State data', data: sanitize_data(data))
        end

        # Log state write operation
        #
        # Records when state is saved to store.
        # INFO level shows step names, DEBUG shows full data (filtered).
        #
        # @param updates [Hash] State updates
        #
        # @example
        #   log_state_write(updates: {steps: {email: {email: 'user@example.com'}}})
        #   # INFO: [MyWizard] State write steps=[:email]
        #   # DEBUG: [MyWizard] State updates data={steps: {...}}
        #
        # @api public
        def log_state_write(updates:)
          steps = updates[:steps]&.keys || []
          log.info('State write', steps:)
          log.debug('State updates', data: sanitize_data(updates))
        end

        # Log step hydration
        #
        # Records when step object is created from data.
        # INFO level shows field names, DEBUG shows values (filtered).
        #
        # @param step_id [Symbol] Step being hydrated
        # @param attributes [Hash] Step attributes
        #
        # @example
        #   log_step_hydration(step_id: :email, attributes: {email: 'user@example.com'})
        #   # INFO: [MyWizard] Step hydrated step=:email fields=[:email]
        #   # DEBUG: [MyWizard] Step data step=:email data={email: 'user@example.com'}
        #
        # @api public
        def log_step_hydration(step_id:, attributes:)
          log.info('Step hydrated', step: step_id, fields: attributes.keys)
          log.debug('Step data', step: step_id, data: sanitize_data(attributes))
        end

        # Log params received from form submission
        #
        # Records incoming request parameters.
        # INFO level shows keys, DEBUG shows values (filtered).
        #
        # @param step_id [Symbol] Step receiving params
        # @param raw_params [Hash] Raw params from request
        # @param permitted_params [Hash] Filtered params after strong_parameters
        #
        # @example
        #   log_params_received(
        #     step_id: :email,
        #     raw_params: {email: '...', extra: '...'},
        #     permitted_params: {email: '...'}
        #   )
        #   # INFO: [MyWizard] Params received step=:email raw_keys=[:email, :extra] permitted_keys=[:email]
        #   # DEBUG: [MyWizard] Params data step=:email raw={...} permitted={...}
        #
        # @api public
        def log_params_received(step_id:, raw_params:, permitted_params:)
          log.info('Params received',
                   step: step_id,
                   raw_keys: raw_params.keys,
                   permitted_keys: permitted_params.keys)
          log.debug('Params data',
                    step: step_id,
                    raw: sanitize_data(raw_params.to_h),
                    permitted: sanitize_data(permitted_params.to_h))
        end

        # Log validation result
        #
        # Records validation checks and errors.
        #
        # @param type [Symbol] Validation type (:step, :path_complete, :path_valid)
        # @param result [Boolean] Validation passed?
        # @param details [Hash] Additional context (step, errors, etc)
        #
        # @example Successful validation
        #   log_validation(type: :step, result: true, step: :email)
        #   # => [MyWizard] Validation type=:step result=true step=:email
        #
        # @example Failed validation
        #   log_validation(type: :step, result: false, step: :email, errors: ["Email can't be blank"])
        #   # => [MyWizard] Validation type=:step result=false step=:email
        #   # => [MyWizard] Validation errors errors=["Email can't be blank"]
        #
        # @api public
        def log_validation(type:, result:, **details)
          log.info('Validation', type: type, result: result, **details)

          if !result && details[:errors]
            log.info('Validation errors', errors: details[:errors])
          end
        end

        # Log callback execution
        #
        # Records before/after callbacks.
        # INFO shows callback name and return type, DEBUG shows full result.
        #
        # @param name [Symbol] Callback name
        # @param result [Object] Callback return value
        #
        # @example
        #   log_callback(name: :before_next_step, result: nil)
        #   # INFO: [MyWizard] Callback executed name=:before_next_step returned=NilClass
        #   # DEBUG: [MyWizard] Callback result name=:before_next_step result=nil
        #
        # @api public
        def log_callback(name:, result:)
          log.info('Callback executed', name: name, returned: result.class.name)
          log.debug('Callback result', name: name, result: result.inspect)
        end

        # Log conditional branch evaluation
        #
        # Records which branch was taken in conditional logic.
        #
        # @param from [Symbol] Source step
        # @param condition [String] Condition label
        # @param result [Boolean] Evaluation result
        # @param chosen [Symbol] Chosen branch
        #
        # @example
        #   log_conditional(
        #     from: :nationality,
        #     condition: 'needs_visa?',
        #     result: true,
        #     chosen: :immigration_status
        #   )
        #   # => [MyWizard] Conditional branch from=:nationality
        #   condition='needs_visa?' result=true chosen=:immigration_status
        #
        # @api public
        def log_conditional(from:, condition:, result:, chosen:)
          log.info('Conditional branch',
                   from: from,
                   condition: condition,
                   result: result,
                   chosen: chosen)
        end

        # Log step save operation
        #
        # Records when step data is persisted.
        # INFO shows field names, DEBUG shows values (filtered).
        #
        # @param step_id [Symbol] Step being saved
        # @param data [Hash] Data being saved
        #
        # @example
        #   log_step_save(step_id: :email, data: {email: 'user@example.com'})
        #   # INFO: [MyWizard] Step saved step=:email fields=[:email]
        #   # DEBUG: [MyWizard] Saved data step=:email data={email: 'user@example.com'}
        #
        # @api public
        def log_step_save(step_id:, data:)
          log.info('Step saved', step: step_id, fields: data.keys)
          log.debug('Saved data', step: step_id, data: sanitize_data(data))
        end

        # Sanitize data using Rails parameter filter
        #
        # Filters sensitive data using Rails.application.config.filter_parameters.
        # Returns unfiltered data if Rails is not available.
        #
        # @param data [Hash] Data to sanitize
        # @return [Hash] Sanitized data with [FILTERED] for sensitive fields
        #
        # @example
        #   # With config.filter_parameters = [:password]
        #   sanitize_data(email: 'user@example.com', password: 'secret')
        #   # => {email: 'user@example.com', password: '[FILTERED]'}
        #
        # @api public
        def sanitize_data(data)
          return data unless defined?(Rails)

          parameter_filter.filter(data)
        end

        # Get Rails parameter filter instance
        #
        # Uses same filters as Rails logs (config.filter_parameters).
        # Cached per wizard instance.
        #
        # @return [ActiveSupport::ParameterFilter]
        #
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
