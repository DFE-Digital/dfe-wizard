module DfE
  module Wizard
    module Core
      # Step module for wizard form objects
      #
      # Provides ActiveModel-based form object functionality for wizard steps.
      # Each step is a standalone form object with validations, attributes, and persistence.
      #
      # Steps are:
      # - Validated independently
      # - Serializable to/from state store
      # - Namespaced for I18n
      # - Rails form helper compatible
      #
      # @example Basic step
      #   module Steps
      #     class Email
      #       include DfE::Wizard::Step
      #
      #       attribute :email, :string
      #       attribute :confirmed, :boolean, default: false
      #
      #       validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
      #       validates :confirmed, acceptance: true
      #
      #       def self.permitted_params
      #         %i[email confirmed]
      #       end
      #     end
      #   end
      #
      # @api public
      module Step
        extend ActiveSupport::Concern

        included do
          include ActiveModel::Model
          include ActiveModel::Attributes
          include ActiveModel::Serialization
        end

        # Initialize step with attributes
        #
        # Accepts hash of attributes and extracts wizard context if present.
        # Reserved keys (wizard, step_id) are not stored as step data.
        #
        # @param step_attributes [Hash] Step data from state store or form params
        #
        # @example
        #   Steps::Email.new(email: 'user@example.com', confirmed: true)
        #
        # @example With wizard context (internal use)
        #   Steps::Email.new(email: '...', wizard: wizard_instance, step_id: :email)
        def initialize(step_attributes = {})
          @step_attributes = step_attributes.dup

          super(**step_attributes)
        end

        # Access to parent wizard
        #
        # Available when step is hydrated by wizard.
        # Allows step to access wizard state or routing helpers.
        #
        # @return [DfE::Wizard::Base, nil]
        #
        # @example
        #   def skip_confirmation?
        #     wizard.step(:profile).admin?
        #   end
        attr_accessor :wizard

        # Step identifier
        #
        # Available when step is hydrated by wizard.
        #
        # @return [Symbol, nil]
        attr_accessor :step_id

        # Serialize step data for storage
        #
        # Returns only the step's own attributes (excludes wizard context).
        # Used by state store when persisting step data.
        #
        # @return [Hash] Serializable step attributes
        #
        # @example
        #   step.serializable_data
        #   # => { email: 'user@example.com', confirmed: true }
        def serializable_data
          attributes.except('wizard', 'step_id')
        end

        # Class methods
        module ClassMethods
          # Define permitted parameters for strong params
          #
          # Subclasses must implement this to declare their form fields.
          # Used by wizard to filter incoming request parameters.
          #
          # @return [Array<Symbol>] List of permitted parameter keys
          # @raise [NotImplementedError] if not implemented by step class
          #
          # @example
          #   class Email
          #     include DfE::Wizard::Step
          #
          #     attribute :email, :string
          #     attribute :confirmed, :boolean
          #
          #     def self.permitted_params
          #       %i[email confirmed]
          #     end
          #   end
          def permitted_params
            raise NotImplementedError, "#{name} must implement .permitted_params"
          end

          # Rails form compatibility
          #
          # Provides custom model name for better I18n and form helpers.
          # Strips module prefix for cleaner error keys.
          #
          # @return [ActiveModel::Name]
          #
          # @example
          #   Steps::Email.model_name.i18n_key  # => :email (not :steps_email)
          #
          # @api public
          def model_name
            ActiveModel::Name.new(self, nil, name.demodulize)
          end
        end
      end
    end
  end
end
