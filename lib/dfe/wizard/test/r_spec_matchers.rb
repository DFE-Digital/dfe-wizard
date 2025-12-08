module DfE
  module Wizard
    module Test
      module RSpecMatchers
        extend RSpec::Matchers::DSL

        # PATH MATCHERS

        # Matcher for next step path
        #
        # @example
        #   expect(wizard).to have_next_step_path(some_path)
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

        # Matcher for previous step path
        #
        # @example
        #   expect(wizard).to have_previous_step_path(some_path)
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

        # Matcher for next step path (alternative syntax)
        #
        # @example
        #   expect(some_path).to be_next_step_path.in(wizard)
        matcher :be_next_step_path do
          chain :in do |wizard_instance|
            @wizard = wizard_instance
          end

          match do |expected_path|
            return false unless @wizard

            @wizard.next_step_path == expected_path
          end

          failure_message do |expected_path|
            return 'No wizard provided - use .in(wizard)' unless @wizard

            actual = @wizard.next_step_path
            "Expected next step path: #{expected_path.inspect}, got: #{actual.inspect}"
          end
        end

        # Matcher for previous step path (alternative syntax)
        #
        # @example
        #   expect(some_path).to be_previous_step_path.in(wizard)
        matcher :be_previous_step_path do
          chain :in do |wizard_instance|
            @wizard = wizard_instance
          end

          match do |expected_path|
            return false unless @wizard

            @wizard.previous_step_path == expected_path
          end

          failure_message do |expected_path|
            return 'No wizard provided - use .in(wizard)' unless @wizard

            actual = @wizard.previous_step_path
            "Expected previous step path: #{expected_path.inspect}, got: #{actual.inspect}"
          end
        end

        # Matcher for step route resolution
        #
        # Tests that a step resolves to the expected URL/path using the route strategy.
        #
        # @example
        #   expect(wizard).to resolve_step(:nationality).to(url_helpers.personal_information_nationality_path)
        #   expect(wizard).to resolve_step(:review).to('/personal-information/review')
        matcher :resolve_step do |step_id|
          chain :to do |expected_path|
            @expected_path = expected_path
          end

          match do |wizard|
            raise ArgumentError, 'Must specify .to(path)' unless @expected_path

            wizard.resolve_step_path(step_id) == @expected_path
          end

          failure_message do |wizard|
            actual = wizard.resolve_step_path(step_id)
            <<~MSG
              Expected step #{step_id.inspect} to resolve to: #{@expected_path.inspect}
              Got: #{actual.inspect}

              Route strategy: #{wizard.route_strategy.class.name}
              #{wizard_inspect(wizard)}
            MSG
          end
        end

        # STEP SYMBOL MATCHERS

        # Matcher for root step check
        # Use when to write to state store any attribute important to show
        # different root steps depending on the scenario
        #
        # @example
        #   expect(wizard).to have_root_step(:name_and_date_of_birth)
        #
        #   # Conditional root
        #   expect(wizard).to have_root_step(
        #     :add_a_level_to_list
        #   ).when(a_level_subjects: [{some_a_level: 'A'}])
        #
        #   # Conditional root
        #   expect(wizard).to have_root_step(
        #     :what_a_level_is_required
        #   ).when(a_level_subjects: [])
        #
        matcher :have_root_step do |expected_root|
          match do |wizard|
            wizard.state_store.write(@state_data) if @state_data.present?

            actual_root = wizard.steps_processor.root_step

            actual_root == expected_root
          end

          chain :when do |state_data|
            @state_data = state_data
          end

          failure_message do |wizard|
            actual_root = wizard.steps_processor.root_step
            "expected wizard to have root node #{expected_root.inspect}, but got #{actual_root.inspect}"
          end

          failure_message_when_negated do |wizard|
            wizard.steps_processor.root_step
            "expected wizard not to have root node #{expected_root.inspect}, but it does"
          end

          description do
            "have root node #{expected_root.inspect}"
          end
        end

        # Matcher for next step symbol
        #
        # @example
        #   expect(wizard).to have_next_step(:nationality)
        #   expect(wizard).to have_next_step(:review).from(:nationality)
        matcher :have_next_step do |expected_step|
          chain :from do |from_step|
            @from_step = from_step
          end

          match do |wizard|
            wizard.current_step_name = @from_step if @from_step
            wizard.next_step == expected_step
          end

          failure_message do |wizard|
            start_step = @from_step || wizard.current_step_name
            wizard.current_step_name = @from_step if @from_step
            actual = wizard.next_step

            <<~MSG
              Expected transition: #{start_step} -> #{expected_step}
              Got:                 #{start_step} -> #{actual}

              From step:          #{start_step}
              Expected next step: #{expected_step}
              Got next step:      #{actual}

              #{wizard_inspect(wizard)}
            MSG
          end
        end

        # Matcher for next step symbol (alternative syntax)
        #
        # @example
        #   expect(:nationality).to be_next_step.in(wizard)
        matcher :be_next_step do
          chain :in do |wizard_instance|
            @wizard = wizard_instance
          end

          match do |expected_step|
            return false unless @wizard

            @wizard.next_step == expected_step
          end

          failure_message do |expected_step|
            return 'No wizard provided - use .in(wizard)' unless @wizard

            actual = @wizard.next_step
            "Expected next step: #{expected_step.inspect}, got: #{actual.inspect}"
          end
        end

        # Matcher for previous step symbol
        #
        # @example
        #   expect(wizard).to have_previous_step(:name_and_date_of_birth)
        #   expect(wizard).to have_previous_step(:nationality).from(:right_to_work_or_study)
        matcher :have_previous_step do |expected_step|
          chain :from do |from_step|
            @from_step = from_step
          end

          match do |wizard|
            wizard.current_step_name = @from_step if @from_step
            wizard.previous_step == expected_step
          end

          failure_message do |wizard|
            start_step = @from_step || wizard.current_step_name
            wizard.current_step_name = @from_step if @from_step
            actual = wizard.previous_step

            <<~MSG
              Expected previous step: #{expected_step.inspect}
              Got: #{actual.inspect}
              From step: #{start_step.inspect}

              #{wizard_inspect(wizard)}
            MSG
          end
        end

        # Matcher for previous step symbol (alternative syntax)
        #
        # @example
        #   expect(:nationality).to be_previous_step.in(wizard)
        matcher :be_previous_step do
          chain :in do |wizard_instance|
            @wizard = wizard_instance
          end

          match do |expected_step|
            return false unless @wizard

            @wizard.previous_step == expected_step
          end

          failure_message do |expected_step|
            return 'No wizard provided - use .in(wizard)' unless @wizard

            actual = @wizard.previous_step
            "Expected previous step: #{expected_step.inspect}, got: #{actual.inspect}"
          end
        end

        # CONDITIONAL BRANCH MATCHER

        # Matcher for conditional branching between steps
        #
        # Tests that a wizard branches from one step to another based on state conditions.
        # Requires `.to(:step)` chain. Optional `.when(params)` chain for state conditions.
        #
        # @example
        #   expect(wizard).to branch_from(:nationality).to(:review).when(nationality: 'british')
        #   expect(wizard).to branch_from(:nationality).to(:right_to_work_or_study).when(nationality: 'canadian')
        matcher :branch_from do |from_step|
          chain :to do |to_step|
            @to_step = to_step
          end

          chain :when do |params|
            @params = params
          end

          match do |wizard|
            raise ArgumentError, 'Must specify .to(:step)' unless @to_step

            wizard.state_store.write(@params) if @params.present?
            wizard.current_step_name = from_step

            wizard.next_step == @to_step
          end

          failure_message do |wizard|
            <<~MSG
              Expected to branch from #{from_step.inspect} to: #{@to_step.inspect}
              Got: #{wizard.next_step.inspect}
              #{@params ? "With params: #{@params.inspect}" : ''}

              #{state_store_data(wizard)}
              #{wizard_inspect(wizard)}
            MSG
          end
        end

        # STEP POSITION MATCHER

        # Matcher for current step position
        #
        # @example
        #   expect(wizard).to be_at_step(:nationality)
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

        # PATH COLLECTION MATCHERS

        # Matcher for complete flow path
        #
        # @example
        #   expect(wizard).to have_flow_path([:name_and_date_of_birth, :nationality, :review])
        matcher :have_flow_path do |expected_steps|
          match { |wizard| wizard.flow_path == expected_steps }
          failure_message do |wizard|
            <<~MSG
              Expected flow_path: #{expected_steps.inspect}
              Got:                #{wizard.flow_path.inspect}

              #{state_store_data(wizard)}
              #{wizard_inspect(wizard)}
            MSG
          end
        end

        # Matcher for saved path (completed steps)
        #
        # @example
        #   expect(wizard).to have_saved_path([:name_and_date_of_birth, :nationality])
        matcher :have_saved_path do |expected_steps|
          match { |wizard| wizard.saved_path == expected_steps }
          failure_message do |wizard|
            <<~MSG
              Expected saved_path: #{expected_steps.inspect}
              Got: #{wizard.saved_path.inspect}

              #{state_store_data(wizard)}
              #{wizard_inspect(wizard)}
            MSG
          end
        end

        # Matcher for valid path (all steps to current are valid)
        #
        # @example
        #   expect(wizard).to have_valid_path([:name_and_date_of_birth, :nationality, :right_to_work_or_study])
        matcher :have_valid_path do |expected_steps|
          match { |wizard| wizard.valid_path == expected_steps }
          failure_message do |wizard|
            <<~MSG
              Expected valid_path: #{expected_steps.inspect}
              Got: #{wizard.valid_path.inspect}

              #{state_store_data(wizard)}
              #{wizard_inspect(wizard)}
            MSG
          end
        end

        # STEP OBJECT MATCHERS

        # Matcher for flow step objects
        #
        # @example
        #   expect(wizard).to have_flow_steps([
        #     Steps::NameAndDateOfBirth,
        #     Steps::Nationality,
        #     Steps::Review
        #   ])
        matcher :have_flow_steps do |expected_steps|
          match do |wizard|
            actual = wizard.flow_steps
            actual.length == expected_steps.length &&
              actual.zip(expected_steps).all? { |a, b| a == b }
          end

          failure_message do |wizard|
            actual = wizard.flow_steps
            <<~MSG
              Expected flow_steps:
              #{expected_steps.map(&:inspect).join("\n")}

              Got:
              #{actual.map(&:inspect).join("\n")}

              #{state_store_data(wizard)}
              #{wizard_inspect(wizard)}
            MSG
          end
        end

        # Matcher for saved step objects
        #
        # @example
        #   expect(wizard).to have_saved_steps([
        #     Steps::NameAndDateOfBirth,
        #     Steps::Nationality
        #   ])
        matcher :have_saved_steps do |expected_steps|
          match do |wizard|
            actual = wizard.saved_steps
            actual.length == expected_steps.length &&
              actual.zip(expected_steps).all? { |a, b| a == b }
          end

          failure_message do |wizard|
            actual = wizard.saved_steps
            <<~MSG
              Expected saved_steps:
              #{expected_steps.map(&:inspect).join("\n")}

              Got:
              #{actual.map(&:inspect).join("\n")}

              #{state_store_data(wizard)}
              #{wizard_inspect(wizard)}
            MSG
          end
        end

        # Matcher for valid step objects
        #
        # @example
        #   expect(wizard).to have_valid_steps([
        #     Steps::NameAndDateOfBirth,
        #     Steps::Nationality,
        #     Steps::RightToWorkOrStudy
        #   ])
        matcher :have_valid_steps do |expected_steps|
          match do |wizard|
            actual = wizard.valid_steps
            actual.length == expected_steps.length &&
              actual.zip(expected_steps).all? { |a, b| a == b }
          end

          failure_message do |wizard|
            actual = wizard.valid_steps
            <<~MSG
              Expected valid_steps:
              #{expected_steps.map(&:inspect).join("\n")}

              Got:
              #{actual.map(&:inspect).join("\n")}

              #{state_store_data(wizard)}
              #{wizard_inspect(wizard)}
            MSG
          end
        end

        # VALIDATION MATCHERS

        # Matcher for valid path to target step
        #
        # Ensures all steps leading to target step are valid.
        #
        # @example
        #   expect(wizard).to be_valid_to(:review)
        matcher :be_valid_to do |target_step|
          match do |wizard|
            wizard.valid_path_to?(target_step)
          end

          failure_message do |wizard|
            flow = wizard.flow_path
            if flow.include?(target_step)
              invalid_steps = flow.reject { |s| wizard.valid?(s) }
              reason = "#{invalid_steps.count} step(s) invalid before reaching #{target_step.inspect}"
            else
              reason = "Step #{target_step.inspect} not in flow path"
            end

            <<~MSG
              Expected valid path to: #{target_step.inspect}
              #{reason}
              Flow path: #{flow.inspect}

              #{state_store_data(wizard)}
              #{wizard_inspect(wizard)}
            MSG
          end
        end

        # Matcher for valid step (alternative syntax)
        #
        # @example
        #   expect(:nationality).to be_valid_step.in(wizard)
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
            step_obj&.valid?
            errors = step_obj&.errors&.full_messages || []

            <<~MSG
              Step invalid: #{step_id.inspect}
              Errors:
              #{errors.map { |e| "  - #{e}" }.join("\n")}

              #{state_store_data(@wizard)}
              #{wizard_inspect(@wizard)}
            MSG
          end
        end

        # STATE STORE MATCHERS

        # Matcher for step attribute presence and value
        #
        # Checks if state store has an attribute with optional value assertion.
        #
        # @example
        #   expect(state_store).to have_step_attribute(:first_name)
        #   expect(state_store).to have_step_attribute(:nationality).with_value('british')
        matcher :have_step_attribute do |attribute|
          chain :with_value do |value|
            @expected_value = value
          end

          match do |state_store|
            # Try to access the attribute via raw data first
            data = state_store.read
            value = data[attribute]

            # Fall back to method call if data lookup fails
            if value.nil?
              value = begin
                state_store.send(attribute)
              rescue StandardError
                nil
              end
            end

            @expected_value.nil? ? !value.nil? : value == @expected_value
          rescue NoMethodError
            false
          end

          failure_message do |state_store|
            data = state_store.read
            actual = data[attribute]

            if actual.nil?
              actual = begin
                state_store.send(attribute)
              rescue StandardError
                nil
              end
            end

            if @expected_value.nil?
              "Expected state_store to respond to #{attribute.inspect}, but got: #{actual.inspect}"
            else
              "Expected #{attribute.inspect} to be #{@expected_value.inspect}, but got: #{actual.inspect}"
            end
          end
        end

        # HELPER METHODS

        # Helper to render wizard inspection output
        #
        # @param wizard [Wizard] The wizard instance to inspect
        # @return [String] Formatted inspection output
        def wizard_inspect(wizard)
          DfE::Wizard::Inspect.new(wizard:).inspect
        end

        # Helper to render state store data
        #
        # @param wizard [Wizard] The wizard instance
        # @return [String] Formatted state store data
        def state_store_data(wizard)
          raw_data = wizard.raw_data[:steps] || {}
          filtered_data = wizard.data[:steps] || {}
          raw_lines = raw_data.empty? ? '  (empty)' : raw_data.map { |k, v| "  #{k}: #{v.inspect}" }.join("\n")
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
