module DfE
  module Wizard
    # Module for building Check Your Answers pages.
    #
    # Include this module in your own presenter class to get helper methods
    # for building check your answers pages. You control the structure, grouping,
    # and formatting - the module provides the building blocks.
    #
    # @example Create your own check answers presenter
    #   class RegisterECTCheckAnswers
    #     include DfE::Wizard::CheckAnswersPresenter
    #
    #     def teacher_details
    #       [
    #         row_for(:review_ect_details, :correct_full_name),
    #         row_for(:email_address, :email),
    #         row_for(:start_date, :start_date),
    #       ]
    #     end
    #
    #     def programme_details
    #       [
    #         row_for(:programme_type, :training_programme),
    #         row_for(:lead_provider, :lead_provider_id),
    #       ]
    #     end
    #
    #     # Override to customize formatting
    #     def format_value(attribute, value)
    #       case attribute
    #       when :start_date
    #         value&.to_fs(:govuk_date)
    #       else
    #         value
    #       end
    #     end
    #   end
    #
    # @example In controller
    #   @check_answers = RegisterECTCheckAnswers.new(@wizard)
    #
    # @example In view
    #   <% @check_answers.teacher_details.each do |row| %>
    #     <dt><%= row.label %></dt>
    #     <dd><%= row.formatted_value %></dd>
    #     <dd><%= link_to "Change", row.change_path %></dd>
    #   <% end %>
    #
    module CheckAnswersPresenter
      # Represents a single row in a check your answers page.
      #
      # Provides access to raw and formatted values, labels from I18n,
      # and change paths for editing.
      class Row
        # @return [Symbol] the step identifier
        attr_reader :step_id

        # @return [Symbol] the attribute name
        attr_reader :attribute

        # @return [DfE::Wizard::Step, nil] the step instance
        attr_reader :step

        # @return [String] the change path with return_to_review parameter
        attr_reader :change_path

        # @return [String, nil] custom label override
        attr_reader :custom_label

        # @return [Object, nil] pre-computed formatted value
        attr_reader :formatted_value

        def initialize(step_id:, attribute:, step:, change_path:, formatted_value: nil, custom_label: nil)
          @step_id = step_id
          @attribute = attribute
          @step = step
          @change_path = change_path
          @formatted_value = formatted_value
          @custom_label = custom_label
        end

        # The raw attribute value from the step.
        #
        # @return [Object] the unformatted value
        def value
          step&.public_send(attribute)
        end

        # The human-readable label for this attribute.
        #
        # Uses custom label if provided, otherwise falls back to
        # the step's human_attribute_name (which uses I18n).
        #
        # @return [String] the label text
        #
        # @example With I18n
        #   # config/locales/en.yml
        #   # en:
        #   #   activemodel:
        #   #     attributes:
        #   #       steps/email_step:
        #   #         email: "Email address"
        #
        #   row.label # => "Email address"
        def label
          return custom_label if custom_label

          if step&.class.respond_to?(:human_attribute_name)
            step.class.human_attribute_name(attribute)
          else
            attribute.to_s.humanize
          end
        end

        # Check if the row has a value.
        #
        # @return [Boolean] true if value is present
        def value?
          value.present?
        end

        # Convert to hash for compatibility.
        #
        # @return [Hash] row data as hash
        def to_h
          {
            step_id: step_id,
            attribute: attribute,
            label: label,
            value: value,
            formatted_value: formatted_value,
            change_path: change_path,
          }
        end
      end

      # @return [DfE::Wizard] the wizard instance
      attr_reader :wizard

      # Initialize the presenter with a wizard.
      #
      # @param wizard [DfE::Wizard] the wizard instance
      def initialize(wizard)
        @wizard = wizard
      end

      # Steps available for review. Override to customize.
      #
      # @return [Array<DfE::Wizard::Step>] steps to include in review
      def reviewable_steps
        wizard.flow_steps
      end

      # Find a step by ID from reviewable steps.
      #
      # @param step_id [Symbol] the step identifier
      # @return [DfE::Wizard::Step, nil] the step or nil if not found
      def find_reviewable_step(step_id)
        reviewable_steps.find { |step| step.step_id == step_id }
      end

      # Build a row for a step attribute.
      #
      # Returns a Row object with access to the value, formatted value,
      # label, and change path. Returns nil if the step is not in
      # reviewable_steps or if the attribute doesn't exist on the step.
      #
      # @param step_id [Symbol] the step identifier
      # @param attribute [Symbol] the attribute name
      # @param label [String, nil] custom label (defaults to step's human_attribute_name)
      # @param change_step [Symbol, nil] override which step the change link goes to
      #
      # @return [Row, nil] row object or nil if step/attribute not available
      #
      # @example Basic row
      #   row = row_for(:email_address, :email)
      #   row.value           # => "john@example.com"
      #   row.formatted_value # => "john@example.com" (or custom via format_value override)
      #   row.label           # => "Email" (from I18n or humanized)
      #   row.change_path     # => "/email?return_to_review=email_address"
      #
      # @example With custom label
      #   row_for(:start_date, :start_date, label: "ECT start date")
      def row_for(step_id, attribute, label: nil, change_step: nil)
        step = find_reviewable_step(step_id)
        return nil unless step
        return nil unless step.respond_to?(attribute)

        raw_value = step.public_send(attribute)

        Row.new(
          step_id: step_id,
          attribute: attribute,
          step: step,
          change_path: change_path_for(change_step || step_id),
          formatted_value: format_value(attribute, raw_value),
          custom_label: label,
        )
      end

      # Format a value for display.
      #
      # Override this method in your presenter to customize how values
      # are displayed. By default, returns the raw value unchanged.
      #
      # @param attribute [Symbol] the attribute name
      # @param value [Object] the raw value from the step
      # @return [Object] the formatted value for display
      #
      # @example Custom formatting
      #   def format_value(attribute, value)
      #     case attribute
      #     when :start_date then value&.to_fs(:govuk_date)
      #     when :working_pattern then value&.humanize
      #     else value
      #     end
      #   end
      def format_value(_attribute, value)
        value
      end

      # Build multiple rows from a step's attributes.
      #
      # Returns an empty array if the step is not in reviewable_steps.
      # Filters out any nil rows (e.g., for non-existent attributes).
      #
      # @param step_id [Symbol] the step identifier
      # @param attributes [Array<Symbol, Hash>] attribute names or hashes with options
      #
      # @return [Array<Row>] array of Row objects
      #
      # @example
      #   rows_for(:personal_details, [:first_name, :last_name, :email])
      #   rows_for(:personal_details, [:first_name, { attribute: :dob, label: "Date of birth" }])
      def rows_for(step_id, attributes)
        step = find_reviewable_step(step_id)
        return [] unless step

        attributes.filter_map do |attr|
          if attr.is_a?(Hash)
            row_for(step_id, attr[:attribute], **attr.except(:attribute))
          else
            row_for(step_id, attr)
          end
        end
      end

      # Generate the change path for a step.
      #
      # @param step_id [Symbol] the step to link to
      # @return [String] the path with return_to_review parameter
      def change_path_for(step_id)
        wizard.resolve_step_path(step_id, return_to_review: step_id)
      end

      # Get all valid steps that have been completed.
      #
      # @return [Array<DfE::Wizard::Step>] array of valid step instances
      def completed_steps
        wizard.valid_steps
      end

      # Get the flow steps (all steps in current path).
      #
      # @return [Array<DfE::Wizard::Step>] array of step instances in flow order
      def flow_steps
        wizard.flow_steps
      end

      # Access the state store for custom data.
      #
      # @return [DfE::Wizard::StateStore] the state store
      def state_store
        wizard.state_store
      end
    end
  end
end
