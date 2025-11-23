# lib/dfe/wizard/repository/model.rb

module DfE
  module Wizard
    module Repository
      # ActiveRecord model repository for wizard state storage
      #
      # Maps wizard state directly to model columns (no JSON column).
      # Returns ALL model attributes - StateStore/Steps filter what they need.
      #
      # This repository is designed for wizards that edit existing models
      # (e.g., user profile updates, settings management). For temporary
      # wizard state, use WizardTable repository instead.
      #
      # @example Basic usage
      #   repo = DfE::Wizard::Repository::Model.new(
      #     record: User.find_or_initialize_by(email: 'new@example.com')
      #   )
      #   repo.read
      #   # => { email: '...', first_name: '...', last_name: '...', ... }
      #
      # @example User profile wizard
      #   class ProfileWizard
      #     include DfE::Wizard::Base
      #     # ...
      #   end
      #
      #   # Steps declare what they need - everything else is ignored:
      #   class PersonalDetailsStep
      #     include DfE::Wizard::Step
      #     attribute :first_name
      #     attribute :last_name
      #   end
      #
      # @example Excluding sensitive columns
      #   class SecureUserRepository < DfE::Wizard::Repository::Model
      #     def excluded_columns
      #       [:password_digest, :api_token, :secret_key]
      #     end
      #   end
      #
      # @example Attribute transformation
      #   class CustomUserRepository < DfE::Wizard::Repository::Model
      #     # Database has: given_name, family_name
      #     # Wizard wants: first_name, last_name
      #     def transform_for_read(data)
      #       data.transform_keys do |key|
      #         case key
      #         when :given_name then :first_name
      #         when :family_name then :last_name
      #         else key
      #         end
      #       end
      #     end
      #
      #     def transform_for_write(data)
      #       data.transform_keys do |key|
      #         case key
      #         when :first_name then :given_name
      #         when :last_name then :family_name
      #         else key
      #         end
      #       end
      #     end
      #   end
      #
      # @example Limiting readable/writable attributes
      #   class LimitedUserRepository < DfE::Wizard::Repository::Model
      #     def readable_attributes
      #       [:first_name, :last_name, :email, :phone]
      #     end
      #
      #     def writable_attributes
      #       [:first_name, :last_name, :phone]
      #     end
      #   end
      class Model
        attr_reader :record

        # Initialize repository with ActiveRecord model instance
        #
        # @param record [ActiveRecord::Base] Model instance (new or persisted)
        # @raise [ArgumentError] if record is nil
        # @raise [ArgumentError] if record is not an ActiveRecord model
        #
        # @example With existing user
        #   user = User.find(123)
        #   repo = DfE::Wizard::Repository::Model.new(record: user)
        #
        # @example With new user
        #   user = User.new(email: 'new@example.com')
        #   repo = DfE::Wizard::Repository::Model.new(record: user)
        def initialize(record:)
          raise ArgumentError, 'record cannot be nil' if record.nil?

          @record = record

          super()
        end

        # Read all model attributes as wizard state
        #
        # Returns ALL readable model attributes (minus any excluded columns).
        # StateStore/Steps will filter to only attributes they declare.
        #
        # @return [Hash] Flat hash of all model attributes with symbolized keys
        #
        # @example
        #   user = User.new(first_name: 'John', last_name: 'Doe', email: 'john@example.com')
        #   repo = DfE::Wizard::Repository::Model.new(record: user)
        #   repo.read
        #   # => { first_name: 'John', last_name: 'Doe', email: 'john@example.com', ... }
        def read
          data = readable_attributes.each_with_object({}) do |attr, hash|
            hash[attr] = record.public_send(attr)
          end

          transform_for_read(data).deep_symbolize_keys
        end

        # Write wizard data to model attributes
        #
        # Only updates attributes that exist in writable_attributes list.
        # Ignores attributes not defined as writable.
        # Saves the record to database with validations.
        #
        # @param hash [Hash] Flat hash of attributes to update
        # @return [void]
        # @raise [ActiveRecord::RecordInvalid] if validations fail
        #
        # @example
        #   repo.write({ first_name: 'Jane', unknown_field: 'ignored' })
        #   # Updates first_name if writable
        #   # Silently ignores unknown_field
        def write(hash)
          transformed = transform_for_write(hash.deep_symbolize_keys)

          assignable = transformed.select { |key, _| writable_attribute?(key) }

          record.assign_attributes(assignable)
          record.save!
        end

        # Clear operation not supported for model repositories
        #
        # Model records represent real business entities with validations
        # and business rules. Clearing them could violate constraints.
        # You can overwrite this in a subclass.
        #
        # @raise [NotImplementedError] always
        #
        def clear
          raise NotImplementedError,
                'Model repository does not support clear operation. ' \
                'Clearing a model record could violate business rules and validations. ' \
                'If you need to clear data, you need to create a subclass and implement #clear.'
        end

        # Check if model has any wizard data
        #
        # Returns true if record is persisted and any readable attribute has a non-nil value.
        #
        # @return [Boolean]
        #
        # @example
        #   user = User.create!(email: 'test@example.com')
        #   repo = DfE::Wizard::Repository::Model.new(record: user)
        #   repo.exists?  # => true
        #
        #   new_user = User.new(email: 'new@example.com')
        #   repo = DfE::Wizard::Repository::Model.new(record: new_user)
        #   repo.exists?  # => false (not persisted)
        def exists?
          record.persisted? && readable_attributes.any? { |attr| record.public_send(attr).present? }
        end

        # Get the underlying ActiveRecord instance
        #
        # @return [ActiveRecord::Base] The model record
        #
        # @example
        #   repo = DfE::Wizard::Repository::Model.new(record: user)
        #   repo.model == user  # => true
        def model
          record
        end

        # Transform attribute names when reading from model
        #
        # Override this method to map database column names to wizard attribute names.
        # This is useful when your database schema uses different naming conventions
        # than your wizard steps.
        #
        # @param data [Hash] Raw model attributes
        # @return [Hash] Transformed attributes for wizard
        #
        # @example Map database columns to wizard attributes
        #   def transform_for_read(data)
        #     data.transform_keys do |key|
        #       case key
        #       when :given_name then :first_name
        #       when :family_name then :last_name
        #       when :birth_date then :date_of_birth
        #       else key
        #       end
        #     end
        #   end
        #
        # @example Complex transformation with nested data
        #   def transform_for_read(data)
        #     address_fields = data.extract!(:address_line_1, :address_line_2, :city, :postcode)
        #     data.merge(
        #       address: {
        #         line_1: address_fields[:address_line_1],
        #         line_2: address_fields[:address_line_2],
        #         city: address_fields[:city],
        #         postcode: address_fields[:postcode]
        #       }
        #     )
        #   end
        def transform_for_read(data)
          data
        end

        # Transform attribute names when writing to model
        #
        # Override this method to map wizard attribute names back to database columns.
        # Should be the inverse of transform_for_read.
        #
        # @param data [Hash] Wizard attributes
        # @return [Hash] Transformed attributes for model
        #
        # @example Map wizard attributes to database columns
        #   def transform_for_write(data)
        #     data.transform_keys do |key|
        #       case key
        #       when :first_name then :given_name
        #       when :last_name then :family_name
        #       when :date_of_birth then :birth_date
        #       else key
        #       end
        #     end
        #   end
        #
        # @example Flatten nested data for database
        #   def transform_for_write(data)
        #     if data[:address].is_a?(Hash)
        #       address = data.delete(:address)
        #       data.merge(
        #         address_line_1: address[:line_1],
        #         address_line_2: address[:line_2],
        #         city: address[:city],
        #         postcode: address[:postcode]
        #       )
        #     else
        #       data
        #     end
        #   end
        def transform_for_write(data)
          data
        end

        # Get list of attributes to read from model
        #
        # Override this to customize which attributes are exposed to wizard.
        # By default, returns all model attributes minus excluded_columns.
        #
        # @return [Array<Symbol>] List of attribute names
        #
        # @example Only expose specific attributes
        #   def readable_attributes
        #     [:first_name, :last_name, :email, :date_of_birth]
        #   end
        #
        # @example Use model's attribute list with exclusions
        #   def readable_attributes
        #     record.attribute_names.map(&:to_sym) - excluded_columns
        #   end
        #
        # @example Dynamic attributes based on model state
        #   def readable_attributes
        #     base_attrs = [:first_name, :last_name, :email]
        #     base_attrs << :admin_notes if record.admin?
        #     base_attrs
        #   end
        def readable_attributes
          return [] unless record.respond_to?(:attribute_names)

          record.attribute_names.map(&:to_sym) - excluded_columns
        end

        # Get list of attributes that can be written to model
        #
        # Override this to customize which attributes can be updated via wizard.
        # By default, returns same list as readable_attributes.
        # This allows you to have read-only attributes.
        #
        # @return [Array<Symbol>] List of attribute names
        #
        # @example Make some attributes read-only
        #   def readable_attributes
        #     [:first_name, :last_name, :email, :created_at]
        #   end
        #
        #   def writable_attributes
        #     [:first_name, :last_name, :email]
        #   end
        #
        # @example Restrict writes based on permissions
        #   def writable_attributes
        #     base_attrs = [:first_name, :last_name, :phone]
        #     base_attrs << :email if record.can_change_email?
        #     base_attrs
        #   end
        #
        # @example Different writable set than readable
        #   def readable_attributes
        #     [:first_name, :last_name, :email, :account_status]
        #   end
        #
        #   def writable_attributes
        #     [:first_name, :last_name]
        #   end
        def writable_attributes
          readable_attributes
        end

        # Columns to exclude from wizard state
        #
        # Override this to hide specific columns from the wizard.
        # By default, returns empty array (no exclusions).
        #
        # Excluded columns won't appear in read() and can't be written via write().
        #
        # @return [Array<Symbol>] List of column names to exclude
        #
        # @example Exclude sensitive fields
        #   def excluded_columns
        #     [:password_digest, :api_token, :secret_key]
        #   end
        #
        # @example Exclude Rails internals
        #   def excluded_columns
        #     [:id, :created_at, :updated_at]
        #   end
        #
        # @example Exclude based on model state
        #   def excluded_columns
        #     base = [:password_digest]
        #     base << :admin_notes unless record.admin?
        #     base
        #   end
        def excluded_columns
          []
        end

        # Check if attribute can be written to model
        #
        # @param attr [Symbol] Attribute name
        # @return [Boolean] true if attribute exists in writable_attributes and has setter
        #
        # @example
        #   writable_attribute?(:first_name)  # => true
        #   writable_attribute?(:nonexistent)  # => false
        def writable_attribute?(attr)
          writable_attributes.include?(attr) && record.respond_to?("#{attr}=")
        end

        private

        # Check if object is an ActiveRecord model
        #
        # @param object [Object] Object to check
        # @return [Boolean]
        def active_record?(object)
          defined?(ActiveRecord::Base) && object.is_a?(ActiveRecord::Base)
        end
      end
    end
  end
end
