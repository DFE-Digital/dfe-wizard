module DfE
  module Wizard
    module Test
      module RSpecMatchers
        extend RSpec::Matchers::DSL

        matcher :have_next_step_path do |expected|
          match { |wiz| wiz.next_step_path == expected }
          failure_message { |wiz| "expected next_step_path to be #{expected.inspect} but got #{wiz.next_step_path.inspect}" }
        end

        matcher :have_previous_step_path do |expected|
          match { |wiz| wiz.previous_step_path == expected }
          failure_message { |wiz| "expected previous_step_path to be #{expected.inspect} but got #{wiz.previous_step_path.inspect}" }
        end

        matcher :be_at_step do |expected_step|
          match { |wizard| wizard.current_step_name == expected_step }
          failure_message { |wizard| "Expected step #{expected_step.inspect}, got #{wizard.current_step_name.inspect}" }
        end

        matcher :have_visited do |*expected_steps|
          match do |wizard|
            path = wizard.path_traversal
            expected_steps.all? { |step| path.include?(step) }
          end
          failure_message do |wizard|
            path = wizard.path_traversal
            missing = expected_steps.reject { |step| path.include?(step) }
            "Expected #{expected_steps.inspect}, missing #{missing.inspect}\nPath: #{path.inspect}"
          end
        end

        matcher :be_able_to_reach do |target_step|
          match do |wizard|
            path = wizard.path_traversal(target_step)
            path.include?(target_step)
          end
          failure_message do |wizard|
            path = wizard.path_traversal(target_step)
            "Cannot reach #{target_step.inspect}\nPath: #{path.inspect}"
          end
        end

        # FIXED: Uses path_traversal(validate: true) instead of removed validators
        matcher :have_valid_path_to do |target_step|
          match do |wizard|
            wizard.step_accessible?(target_step)
          end

          failure_message do |wizard|
            results = wizard.path_traversal(target_step, validate: true)
            path = wizard.path_traversal(target_step)

            invalid = results.find { |r| r[:visited] && !r[:valid] }
            unvisited = results.find { |r| !r[:visited] }

            reason = if invalid
                       "Step #{invalid[:step]} has errors: #{invalid[:errors].join(', ')}"
                     elsif unvisited
                       "Step #{unvisited[:step]} not visited"
                     else
                       "Path validation failed"
                     end

            validation_output = results.map do |r|
              status = "#{r[:visited] ? '✓' : '✗'} visited, #{r[:valid] ? '✓' : '✗'} valid"
              errors = r[:errors].any? ? " (#{r[:errors].join(', ')})" : ""
              "  #{r[:step]}: [#{status}]#{errors}"
            end.join("\n")

            <<~MSG
              Expected valid path to #{target_step.inspect}

              #{reason}

              Path: #{path.inspect}

              Validation results:
              #{validation_output}

              State store data:
              #{format_state_data(wizard)}
            MSG
          end

          def format_state_data(wizard)
            data = wizard.state_store.read
            steps = data[:steps] || {}
            steps.map { |k, v| "  #{k}: #{v.inspect}" }.join("\n")
          end
        end

        matcher :be_reachable do
          chain :in do |wizard_instance|
            @wizard = wizard_instance
          end

          match do |step_id|
            return false unless @wizard
            @wizard.path_traversal(step_id).include?(step_id)
          end

          failure_message do |step_id|
            return "No wizard provided - use .in(wizard)" unless @wizard
            path = @wizard.path_traversal(step_id)
            "Cannot reach #{step_id.inspect} (path: #{path.inspect})"
          end
        end

        matcher :be_accessible do
          chain :in do |wizard_instance|
            @wizard = wizard_instance
          end

          match do |step_id|
            return false unless @wizard
            @wizard.step_accessible?(step_id)
          end

          failure_message do |step_id|
            return "No wizard provided - use .in(wizard)" unless @wizard
            path = @wizard.path_traversal(step_id)

            if !path.include?(step_id)
              "Step #{step_id.inspect} not in path: #{path.inspect}"
            else
              results = @wizard.path_traversal(step_id, validate: true)
              invalid = results.find { |r| r[:visited] && !r[:valid] }

              if invalid
                "Step #{step_id.inspect} not accessible - #{invalid[:step]} is invalid"
              else
                "Step #{step_id.inspect} not accessible"
              end
            end
          end
        end
      end
    end
  end
end
