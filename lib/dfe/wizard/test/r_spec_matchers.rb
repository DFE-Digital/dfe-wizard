module DfE
  module Wizard
    module Test
      module RSpecMatchers
        extend RSpec::Matchers::DSL

        matcher :have_next_step_path do |expected|
          match { |wiz| wiz.next_step_path == expected }

          failure_message do |wiz|
            <<~MSG
              Expected next_step_path: #{expected.inspect}
              Got: #{wiz.next_step_path.inspect}

              #{wizard_inspect(wiz)}
            MSG
          end
        end

        matcher :have_previous_step_path do |expected|
          match { |wiz| wiz.previous_step_path == expected }

          failure_message do |wiz|
            <<~MSG
              Expected previous_step_path: #{expected.inspect}
              Got: #{wiz.previous_step_path.inspect}

              #{wizard_inspect(wiz)}
            MSG
          end
        end

        matcher :be_at_step do |expected_step|
          match { |wizard| wizard.current_step_name == expected_step }

          failure_message do |wizard|
            <<~MSG
              Expected current step: #{expected_step.inspect}
              Got: #{wizard.current_step_name.inspect}

              #{wizard_inspect(wizard)}
            MSG
          end
        end

        matcher :be_in_flow do
          chain :in do |wizard_instance|
            @wizard = wizard_instance
          end

          match do |step_id|
            return false unless @wizard

            @wizard.in_flow?(step_id)
          end

          failure_message do |step_id|
            return 'No wizard provided - use .in(wizard)' unless @wizard

            <<~MSG
              Step not in flow: #{step_id.inspect}
              Flow path: #{@wizard.flow_path.inspect}

              #{state_store_data(@wizard)}

              #{wizard_inspect(@wizard)}
            MSG
          end
        end

        matcher :have_in_flow do |*expected_steps|
          match do |wizard|
            expected_steps.all? { |step| wizard.in_flow?(step) }
          end

          failure_message do |wizard|
            flow = wizard.flow_path
            missing = expected_steps.reject { |step| wizard.in_flow?(step) }

            <<~MSG
              Expected steps in flow: #{expected_steps.inspect}
              Missing: #{missing.inspect}
              Flow path: #{flow.inspect}

              #{state_store_data(wizard)}

              #{wizard_inspect(wizard)}
            MSG
          end
        end

        matcher :be_saved do
          chain :in do |wizard_instance|
            @wizard = wizard_instance
          end

          match do |step_id|
            return false unless @wizard

            @wizard.saved?(step_id)
          end

          failure_message do |step_id|
            return 'No wizard provided - use .in(wizard)' unless @wizard

            <<~MSG
              Step not saved: #{step_id.inspect}
              Saved path: #{@wizard.saved_path.inspect}

              #{state_store_data(@wizard)}

              #{wizard_inspect(@wizard)}
            MSG
          end
        end

        matcher :have_saved do |*expected_steps|
          match do |wizard|
            expected_steps.all? { |step| wizard.saved?(step) }
          end

          failure_message do |wizard|
            saved = wizard.saved_path
            missing = expected_steps.reject { |step| wizard.saved?(step) }

            <<~MSG
              Expected saved steps: #{expected_steps.inspect}
              Missing: #{missing.inspect}
              Saved path: #{saved.inspect}

              #{state_store_data(wizard)}

              #{wizard_inspect(wizard)}
            MSG
          end
        end

        matcher :be_valid_to do |target_step|
          match do |wizard|
            wizard.valid_path_to?(target_step)
          end

          failure_message do |wizard|
            flow = wizard.flow_path(target_step)
            valid = wizard.valid_path(target_step)

            if flow.present?
              invalid_steps = flow.reject { |s| wizard.valid?(s) }
              reason = "#{invalid_steps.count} step(s) invalid before reaching #{target_step.inspect}"

              invalid_steps_details = invalid_steps.map do |step_id|
                step_obj = wizard.step(step_id)
                step_obj.valid?
                errors = step_obj.errors.full_messages

                "  ✗ #{step_id}:\n" + errors.map { |e| "    - #{e}" }.join("\n")
              end.join("\n\n")
            else
              reason = "Step #{target_step.inspect} not in flow path"
              invalid_steps_details = ''
            end

            <<~MSG
              Expected valid path to: #{target_step.inspect}

              #{reason}

              Flow path: #{flow.inspect}
              Valid path: #{valid.inspect}

              #{"Invalid steps:\n#{invalid_steps_details}\n" if invalid_steps_details.present?}
              #{state_store_data(wizard)}

              #{wizard_inspect(wizard)}
            MSG
          end
        end

        matcher :be_valid_step do
          chain :in do |wizard_instance|
            @wizard = wizard_instance
          end

          match do |step_id|
            return false unless @wizard

            @wizard.valid?(step_id)
          end

          failure_message do |step_id|
            return 'No wizard provided - use .in(wizard)' unless @wizard

            step_obj = @wizard.step(step_id)
            step_obj.valid?
            errors = step_obj.errors.full_messages

            <<~MSG
              Step invalid: #{step_id.inspect}

              Errors:
              #{errors.map { |e| "  - #{e}" }.join("\n")}

              #{state_store_data(@wizard)}

              #{wizard_inspect(@wizard)}
            MSG
          end
        end

        matcher :branch_to do |expected_step|
          chain :from do |from_step|
            @from_step = from_step
          end

          match do |wizard|
            return false unless @from_step

            # Simulate being at the from_step and check next step
            wizard_at_step = wizard.class.new(
              current_step: @from_step,
              state_store: wizard.state_store,
            )
            wizard_at_step.next_step == expected_step
          end

          failure_message do |wizard|
            return 'No from step provided - use .from(step)' unless @from_step

            wizard_at_step = wizard.class.new(
              current_step: @from_step,
              state_store: wizard.state_store,
            )
            actual_next = wizard_at_step.next_step

            <<~MSG
              Expected branch from #{@from_step.inspect} to: #{expected_step.inspect}
              Got: #{actual_next.inspect}

              #{state_store_data(wizard)}

              #{wizard_inspect(wizard)}
            MSG
          end
        end

        def wizard_inspect(wizard)
          DfE::Wizard::Core::Inspect.new(wizard:).inspect
        end

        def state_store_data(wizard)
          raw_data = wizard.raw_data[:steps] || {}
          filtered_data = wizard.data[:steps] || {}

          raw_lines = if raw_data.empty?
                        '  (empty)'
                      else
                        raw_data.map { |k, v| "  #{k}: #{v.inspect}" }.join("\n")
                      end

          filtered_lines = if filtered_data.empty?
                             '  (empty)'
                           else
                             filtered_data.map { |k, v| "  #{k}: #{v.inspect}" }.join("\n")
                           end

          <<~DATA
            ┌─ STATE STORE DATA ─────────────────────────┐
            │ Raw:
            #{raw_lines}
            │ Filtered:
            #{filtered_lines}
            └────────────────────────────────────────────┘
          DATA
        end
      end
    end
  end
end
