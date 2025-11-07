# lib/dfe/wizard/state_store/base.rb
# frozen_string_literal: true

module DfE
  module Wizard
    module StateStore
      # Base state store interface
      #
      # Provides data storage AND query methods for wizard-specific logic.
      #
      # Expected data structure:
      # ```
      # {
      #   steps: {
      #     step_name: { attr1: value1, attr2: value2 },
      #     ...
      #   },
      #   ...metadata...
      # }
      # ```
      #
      # Implement storage methods. Add domain query methods in subclasses.
      #
      # @example
      #   class Wizards::StateStores::RegisterECT < DfE::Wizard::StateStore::Base
      #     def in_trs?
      #       step_data(:national_insurance_number)[:in_trs] == true
      #     end
      #
      #     def matches_trs_dob?
      #       step_data(:national_insurance_number)[:matches_dob] == true
      #     end
      #
      #     def active_at_school?
      #       step_data(:find_ect)[:active] == true
      #     end
      #   end
      #
      # @api public
      class Base
        # Read all wizard state
        #
        # @return [Hash]
        def read
          raise NotImplementedError
        end

        # Write state (deep merge)
        #
        # @param updates [Hash]
        # @return [void]
        def write(updates)
          raise NotImplementedError
        end

        # Clear all state
        #
        # @return [void]
        def clear
          raise NotImplementedError
        end

        # Write a single step (convenience)
        #
        # @param step_id [Symbol]
        # @param data [Hash]
        # @return [void]
        def write_step(step_id, data)
          steps = read[:steps] || {}
          write(steps: steps.merge(step_id => data))
        end

        # Get state key (optional)
        #
        # @return [String, nil]
        def state_key
          nil
        end

        # ========== Query Helpers ==========
        # Use these to access step data. Override in subclasses for domain logic.

        # Get data from a specific step
        #
        # @param step_id [Symbol]
        # @return [Hash]
        def step_data(step_id)
          read.dig(:steps, step_id) || {}
        end

        # Get a value from a step
        #
        # @param step_id [Symbol]
        # @param key [Symbol, String]
        # @param default [Object]
        # @return [Object]
        def step_value(step_id, key, default: nil)
          step_data(step_id).fetch(key, default)
        end

        # Get metadata value
        #
        # @param key [Symbol, String]
        # @param default [Object]
        # @return [Object]
        def metadata(key, default: nil)
          read.fetch(key, default)
        end

        # Check if a step has data
        #
        # @param step_id [Symbol]
        # @return [Boolean]
        def step_with_data?(step_id)
          step_data(step_id).present?
        end
      end
    end
  end
end
