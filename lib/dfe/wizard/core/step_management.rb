module DfE
  module Wizard
    module Core
      # Step lifecycle management
      #
      # Handles step lookup, instantiation, and attribute extraction.
      # Called by the wizard to load and prepare steps.
      #
      # @api public
      module StepManagement
        # Get a hydrated step object
        #
        # @param step_id [Symbol]
        # @return [Object] Hydrated step instance
        def step(step_id)
          @cached_steps ||= {}
          @cached_steps[step_id] ||= hydrate_step(step_id)
        end

        # Hydrate a step from state store
        #
        # @param step_id [Symbol]
        # @return [Object] Instantiated step
        def hydrate_step(step_id)
          step_class = find_step(step_id)
          persisted_data = raw_step_data(step_id)

          # ONLY merge current params if we're hydrating the CURRENT step
          merged_data = if step_id == current_step_name
                          persisted_data.merge(current_step_params)
                        else
                          persisted_data
                        end

          log_step_hydration(step_id:, attributes: merged_data)

          step_class.new(**merged_data.symbolize_keys.merge(wizard: self, step_id: step_id))
        end

        # Find the step class for a given step ID
        #
        # @param step_name [Symbol] The step identifier
        # @return [Class] The step class
        # @raise [StandardError] If step not found
        #
        # @example
        #   wizard.find_step(:email)  # => EmailStep
        def find_step(step_name)
          steps_processor.find_step(step_name)
        end

        # Get the current step instance
        #
        # Instantiates the step class with current state and parameters.
        # Caches the instance.
        #
        # @return [DfE::Wizard::Step]
        #
        # @example
        #   step = wizard.current_step
        #   step.valid?  # => true/false
        def current_step
          @current_step ||= begin
            klass = find_step(current_step_name)
            params = fetch_step_attributes

            klass.new(**params.symbolize_keys.merge(wizard: self, step_id: current_step_name))
          end
        end

        # Extracts permitted parameters for the current step.
        #
        # Pulls parameters relevant to the current step and applies the
        # allowlist from `permitted_params`.
        #
        # @return [Hash] Permitted param values for the current step
        #
        # @example In Rails controller:
        #   wizard.current_step_params  # => { email: "em@il.com" }
        #
        # @example Fallback when params not present
        #   # If there are no params for current step, returns {}
        #
        def current_step_params
          params = if @current_step_params.is_a?(ActionController::Parameters)
                     @current_step_params.require(current_step_name).permit(permitted_params)
                   else
                     @current_step_params.fetch(current_step_name, {})
                   end

          raw_params = if @current_step_params.respond_to?(:to_unsafe_h)
                         @current_step_params.to_unsafe_h
                       else
                         @current_step_params
                       end

          params.tap do
            if @current_step_params.present?
              log_params_received(
                step_id: current_step_name,
                raw_params:,
                permitted_params: params,
              )
            end
          end
        rescue ActionController::ParameterMissing, NotImplementedError => error
          log_params_error(step_id: current_step_name, error:)
          {}
        end

        # Returns the permitted parameter keys for the current step class.
        #
        # This should invoke the `.permitted_params` class method on the step class,
        # which each wizard step should define to advertise its strong param contract.
        # Used to ensure that parameter whitelisting is handled consistently per step.
        #
        # @return [Array<Symbol>] Array of permitted param keys
        #
        # @example
        #   # In step class
        #   def self.permitted_params
        #     [:email, :name]
        #   end
        #
        #   # In wizard
        #   wizard.permitted_params  # => [:email, :name]
        #
        # @api public
        def permitted_params
          find_step(current_step_name).permitted_params
        end

        # Extract step attributes from state store and request params
        #
        # Merges persisted step data with incoming form parameters,
        # giving precedence to form parameters.
        #
        # @return [Hash] Attributes for step initialization
        #
        # @api public
        def fetch_step_attributes
          step_data(current_step_name).deep_merge(current_step_params)
        end

        # Get step objects for all steps in current flow
        #
        # @return [Array<DfE::Wizard::Step>] All flow steps
        # @see Navigation#steps_in_flow (same thing, alias)
        def flow_steps
          flow_path.map { |step_id| step(step_id) }
        end

        # Get hydrated step objects for steps with saved data
        #
        # Returns instantiated Step objects for all steps in current flow
        # where user has entered data. Useful for rendering forms with
        # pre-filled values or showing saved progress.
        #
        # @return [Array<DfE::Wizard::Step>] Step objects with saved data
        #
        # @example Pre-fill form with saved data
        #   wizard.steps_saved.each do |step|
        #     render_form(step, data: step.data)
        #   end
        #
        # @example Show saved progress
        #   wizard.steps_saved.count  # => 2 steps completed
        #
        # @see #saved_path For step IDs only
        # @see Navigation#steps_in_flow For all flow steps
        # @api public
        def saved_steps
          saved_path.map { |step_id| step(step_id) }
        end

        # Get step objects for steps with valid data
        #
        # @return [Array<DfE::Wizard::Step>] Valid steps
        # @see Validation#steps_valid (same thing, alias)
        def valid_steps
          valid_path.map { |step_id| step(step_id) }
        end
      end
    end
  end
end
