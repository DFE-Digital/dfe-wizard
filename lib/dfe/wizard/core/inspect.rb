module DfE
  module Wizard
    module Core
      # Comprehensive wizard introspection for development/debugging
      #
      # Shows all wizard state: flow, saved, valid paths, validation status,
      # instance variables, and full state store data.
      #
      # IMPORTANT: Only for local development! Use Rails.env.local? guard.
      #
      # @example
      #   # In wizard class
      #   def inspect
      #     DfE::Wizard::Core::Inspect.new(wizard: self) if Rails.env.local?
      #   end
      #
      #   # Usage
      #   puts wizard  # shows full debug output
      #
      class Inspect
        def initialize(wizard:)
          @wizard = wizard
        end

        # Generate comprehensive inspect output
        #
        # Shows three-layer state: flow path, saved path, valid path.
        # Displays validation status, instance variables (unmasked), and state store.
        #
        # @return [String] Formatted debug output
        #
        def inspect
          <<~OUTPUT
            #{header}
            #{state_section}
            #{validation_section}
            #{errors_section}
            #{vars_section}
            #{store_section}
          OUTPUT
        end

        alias to_s inspect

        private

        attr_reader :wizard

        def header
          "#<#{wizard.class.name}:0x#{wizard.object_id.to_s(16)}>"
        end

        def state_section
          <<~STATE
            ┌─ STATE LAYERS ─────────────────────────────┐
            │ Current Step: #{wizard.current_step_name}
            │ Flow Path:    #{wizard.flow_path.inspect}
            │ Saved Path:   #{wizard.saved_path.inspect}
            │ Valid Path:   #{wizard.valid_path.inspect}
            └────────────────────────────────────────────┘
          STATE
        end

        def validation_section
          invalid = wizard.flow_path.reject { |sid| wizard.valid?(sid) }
          status = if invalid.empty?
                     '✓ All steps valid'
                   else
                     "✗ Invalid: #{invalid.inspect}"
                   end

          <<~VALIDATION
            ┌─ VALIDATION ───────────────────────────────┐
            │ #{status}
            └────────────────────────────────────────────┘
          VALIDATION
        end

        def errors_section
          invalid_step = wizard.flow_path.find { |step_id| !wizard.valid?(step_id) }
          return '' if invalid_step.blank?

          step = wizard.step(invalid_step)

          step.valid?

          errors = step.errors.messages || {}

          error_lines = errors.map do |field, msgs|
            "#{field}: #{msgs.to_a.join(', ')}"
          end

          <<~ERRORS
            ┌─ ERRORS ───────────────────────────────────┐
             #{invalid_step}: #{error_lines}
            └────────────────────────────────────────────┘
          ERRORS
        end

        def vars_section
          vars_content = wizard.instance_variables.map do |var|
            value = wizard.instance_variable_get(var).inspect.truncate(60)
            "│ #{var}: #{value}"
          end.join("\n")

          <<~VARS
            ┌─ INSTANCE VARIABLES ───────────────────────┐
            #{vars_content}
            └────────────────────────────────────────────┘
          VARS
        end

        def store_section
          raw_data = wizard.raw_data[:steps] || {}
          data = wizard.data[:steps] || {}
          orphaned = wizard.orphaned_steps_data.keys

          raw_lines = raw_data.map do |step_id, values|
            "  #{step_id}: #{values.inspect}"
          end.join("\n")

          data_lines = data.map do |step_id, values|
            "  #{step_id}: #{values.inspect}"
          end.join("\n")

          orphaned_line = orphaned.any? ? "│ Orphaned: #{orphaned.inspect}\n" : ''

          <<~STORE
            ┌─ STATE STORE ──────────────────────────────┐
            │ Metadata: #{wizard.all_metadata}
            │ Raw Steps:
            #{raw_lines.present? ? raw_lines.split("\n").map { |l| "│ #{l}" }.join("\n") : '│  (empty)'}
            │ Filtered:
            #{data_lines.present? ? data_lines.split("\n").map { |l| "│ #{l}" }.join("\n") : '│  (empty)'}
            #{orphaned_line}└────────────────────────────────────────────┘
          STORE
        end
      end
    end
  end
end
