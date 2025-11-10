module DfE
  module Wizard
    module Test
      # RSpec matchers for wizard testing
      #
      # Provides expressive matchers for wizard state assertions with rich failure output
      #
      # @example In spec_helper.rb
      #   require 'dfe/wizard/test/matchers'
      #
      #   RSpec.configure do |config|
      #     config.include DfE::Wizard::Test::Matchers
      #   end
      #
      # @api public
      module RSpecMatchers
        extend RSpec::Matchers::DSL

        # Check if wizard is at a specific step
        #
        # @example
        #   expect(wizard).to be_at_step(:email)
        matcher :be_at_step do |expected_step|
          match do |wizard|
            wizard.current_step_name == expected_step
          end

          failure_message do |wizard|
            <<~MSG
              Expected wizard to be at step #{expected_step.inspect}

              Current step: #{wizard.current_step_name.inspect}

              Path traversal: #{wizard.path_traversal.inspect}

              State store data:
              #{format_state_data(wizard.state_store.read)}

              Current step params:
              #{format_params(wizard.instance_variable_get(:@step_params))}
            MSG
          end

          failure_message_when_negated do |_wizard|
            "Expected wizard NOT to be at step #{expected_step.inspect}, but it is"
          end

          def format_state_data(data)
            return '  (empty)' if data.empty?

            data.map { |k, v| "  #{k}: #{v.inspect}" }.join("\n")
          end

          def format_params(params)
            return '  (none)' if params.nil? || params.empty?

            params.to_h.map { |k, v| "  #{k}: #{v.inspect}" }.join("\n")
          end
        end

        # Check if wizard has visited specific steps
        #
        # @example
        #   expect(wizard).to have_visited(:name, :dob)
        matcher :have_visited do |*expected_steps|
          match do |wizard|
            path = wizard.path_traversal
            expected_steps.all? { |step| path.include?(step) }
          end

          failure_message do |wizard|
            path = wizard.path_traversal
            missing = expected_steps.reject { |step| path.include?(step) }

            <<~MSG
              Expected wizard to have visited: #{expected_steps.inspect}
              Missing steps: #{missing.inspect}

              Actual path: #{path.inspect}
              Current step: #{wizard.current_step_name.inspect}

              State store data:
              #{format_state_data(wizard.state_store.read)}
            MSG
          end

          def format_state_data(data)
            return '  (empty)' if data.empty?

            steps_data = data[:steps] || {}
            steps_data.map do |step_id, step_data|
              "  #{step_id}: #{step_data.inspect}"
            end.join("\n")
          end
        end

        # Check if wizard can reach a target step
        #
        # @example
        #   expect(wizard).to be_able_to_reach(:review)
        matcher :be_able_to_reach do |target_step|
          match do |wizard|
            path = wizard.path_traversal(target_step)
            path.include?(target_step)
          end

          failure_message do |wizard|
            path = wizard.path_traversal(target_step)

            <<~MSG
              Expected wizard to be able to reach #{target_step.inspect}

              Path calculated: #{path.inspect}
              Target reached: #{path.include?(target_step)}

              Current step: #{wizard.current_step_name.inspect}
              All nodes: #{wizard.steps_processor.nodes.keys.inspect}

              Reason: #{diagnose_unreachable(wizard, target_step)}

              State store data:
              #{format_state_data(wizard.state_store.read)}
            MSG
          end

          def diagnose_unreachable(wizard, target)
            path = wizard.path_traversal(target)

            if !wizard.steps_processor.nodes.key?(target)
              "Target step #{target.inspect} does not exist in graph"
            elsif path.empty?
              'Path is empty - starting from non-root or unreachable'
            else
              last_reached = path.last
              "Path stops at #{last_reached.inspect} - check conditional logic or validations"
            end
          end

          def format_state_data(data)
            return '  (empty)' if data.empty?

            steps_data = data[:steps] || {}
            steps_data.map do |step_id, step_data|
              "  #{step_id}: #{step_data.inspect}"
            end.join("\n")
          end
        end

        # Check if wizard has valid path to target
        #
        # @example
        #   expect(wizard).to have_valid_path_to(:confirmation)
        matcher :have_valid_path_to do |target_step|
          match do |wizard|
            wizard.path_valid_to?(target_step)
          end

          failure_message do |wizard|
            invalid_step = wizard.first_invalid_step(target_step:)
            path = wizard.path_traversal(target_step)

            <<~MSG
              Expected wizard to have valid path to #{target_step.inspect}

              Path: #{path.inspect}
              First invalid step: #{invalid_step.inspect}

              #{format_validation_errors(wizard, invalid_step, path)}

              State store data:
              #{format_state_data(wizard.state_store.read)}

              Current step params:
              #{format_params(wizard.instance_variable_get(:@step_params))}
            MSG
          end

          def format_validation_errors(wizard, invalid_step, _path)
            return 'All steps valid' unless invalid_step

            step_obj = wizard.step(invalid_step)
            errors = step_obj.errors.full_messages

            <<~ERRORS
              Validation errors on #{invalid_step.inspect}:
              #{errors.map { |e| "  - #{e}" }.join("\n")}

              Step data:
              #{format_step_data(step_obj)}
            ERRORS
          end

          def format_step_data(step)
            step.serializable_data.map { |k, v| "  #{k}: #{v.inspect}" }.join("\n")
          end

          def format_state_data(data)
            return '  (empty)' if data.empty?

            steps_data = data[:steps] || {}
            steps_data.map do |step_id, step_data|
              "  #{step_id}: #{step_data.inspect}"
            end.join("\n")
          end

          def format_params(params)
            return '  (none)' if params.nil? || params.empty?

            params.to_h.map { |k, v| "  #{k}: #{v.inspect}" }.join("\n")
          end
        end

        # Check if step is reachable (exists in graph and has path to it)
        #
        # @example
        #   expect(:immigration_status).to be_reachable.in(wizard)
        matcher :be_reachable do
          chain :in do |wizard_instance|
            @wizard = wizard_instance
          end

          match do |step_id|
            return false unless @wizard

            @wizard.steps_processor.nodes.key?(step_id) &&
              @wizard.path_traversal(step_id).include?(step_id)
          end

          failure_message do |step_id|
            return 'No wizard provided - use .in(wizard)' unless @wizard

            exists = @wizard.steps_processor.nodes.key?(step_id)
            path = @wizard.path_traversal(step_id)

            <<~MSG
              Expected step #{step_id.inspect} to be reachable

              Step exists in graph: #{exists}
              Path to step: #{path.inspect}
              Includes target: #{path.include?(step_id)}

              All nodes: #{@wizard.steps_processor.nodes.keys.inspect}
              Current wizard step: #{@wizard.current_step_name.inspect}
            MSG
          end
        end

        # Check if step is accessible (reachable and all previous steps valid)
        #
        # @example
        #   expect(:confirmation).to be_accessible.in(wizard)
        matcher :be_accessible do
          chain :in do |wizard_instance|
            @wizard = wizard_instance
          end

          match do |step_id|
            return false unless @wizard

            @wizard.current_step_accessible? if @wizard.current_step_name == step_id
          end

          failure_message do |step_id|
            return 'No wizard provided - use .in(wizard)' unless @wizard

            path = @wizard.path_traversal(step_id)

            <<~MSG
              Expected step #{step_id.inspect} to be accessible

              Path to step: #{path.inspect}

              #{format_accessibility_check(@wizard, step_id, path)}

              State store data:
              #{format_state_data(@wizard.state_store.read)}
            MSG
          end

          def format_accessibility_check(wizard, step_id, path)
            return 'Step not in path' unless path.include?(step_id)

            previous_steps = path[0...-1]

            invalid_steps = previous_steps.reject do |prev_step|
              step_obj = wizard.step(prev_step)
              step_obj.valid?
            end

            if invalid_steps.any?
              "Invalid previous steps: #{invalid_steps.inspect}"
            else
              'All previous steps valid'
            end
          end

          def format_state_data(data)
            return '  (empty)' if data.empty?

            steps_data = data[:steps] || {}
            steps_data.map do |step_id, step_data|
              "  #{step_id}: #{step_data.inspect}"
            end.join("\n")
          end
        end
      end
    end
  end
end
