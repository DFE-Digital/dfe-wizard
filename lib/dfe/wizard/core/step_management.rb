# frozen_string_literal: true

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

            klass.new(params.merge(wizard: self, step_id: current_step_name))
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
          @step_params.require(current_step_name).permit(permitted_params)
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
          step_object_class.permitted_params
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
          step_data = read_step_data(current_step_name)
          form_params = step_params[current_step_name] || {}

          step_data.deep_merge(form_params.to_h)
        end
      end
    end
  end
end
