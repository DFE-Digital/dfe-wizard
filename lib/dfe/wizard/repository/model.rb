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

        # Save state atomically by replacing entire data
        #
        # @param hash [Hash] Complete state to save
        # @return [void]
        def save(hash)
          write(hash)
        end

        # Execute an operation in the repository context
        #
        # Instantiates the operation class with this repository and the step,
        # then calls its `execute` method.
        #
        # @param operation_class [Class] Operation class to instantiate and execute
        #   Must respond to `new(repository:, step:).execute`
        # @param step [Object] Step instance containing data to operate on
        # @return [Hash] Operation result hash
        #   - `:success` [Boolean] Whether operation succeeded
        #   - `:errors` [Hash] Validation errors if success is false
        #
        # @example Execute validation operation
        #   result = repo.execute_operation(
        #     operation_class: DfE::Wizard::Operations::Validate,
        #     step: step_instance
        #   )
        #   # => { success: true } or { success: false, errors: {...} }
        #
        # @example Execute persistence operation
        #   result = repo.execute_operation(
        #     operation_class: DfE::Wizard::Operations::Persist,
        #     step: step_instance
        #   )
        #   # => { success: true }
        #
        # @see DfE::Wizard::Operations::Validate For validation operation
        # @see DfE::Wizard::Operations::Persist For persistence operation
        # @api public
        def execute_operation(operation_class:, step:)
          operation_class.new(repository: self, step:).execute
        end

        # Clear operation not supported for model repositories
        #
        # Model records represent real business entities with validations
        # and business rules. Clearing them could violate constraints.
        # You can overwrite this in a subclass.
        #
        # @raise [NotImplementedError] always
        def clear
          raise NotImplementedError,
                'Model repository does not support clear operation. ' \
                'Clearing a model record could violate business rules and validations. ' \
                'If you need to clear data, you need to create a subclass and implement #clear.'
        end

        # Get readable attributes from the model
        #
        # Override this to customize which attributes are readable.
        # By default, returns all columns except excluded_columns.
        #
        # @return [Array<Symbol>] List of readable attribute names
        #
        # @example Only expose public fields
        #   def readable_attributes
        #     [:first_name, :last_name, :email, :phone]
        #   end
        def readable_attributes
          record.class.column_names.map(&:to_sym) - excluded_columns
        end

        # Get writable attributes for the model
        #
        # Override this to restrict which attributes can be updated via wizard.
        # By default, same as readable_attributes.
        #
        # @return [Array<Symbol>] List of writable attribute names
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
        #   writable_attribute?(:first_name) # => true
        #   writable_attribute?(:nonexistent) # => false
        def writable_attribute?(attr)
          writable_attributes.include?(attr) && record.respond_to?("#{attr}=")
        end

        # Transform data for reading (hook for subclasses)
        #
        # Override to rename, convert, or filter attributes when reading.
        # Default implementation returns data unchanged.
        #
        # @param data [Hash] Raw attribute hash from model
        # @return [Hash] Transformed hash
        #
        # @example Rename fields
        #   def transform_for_read(data)
        #     data.transform_keys do |key|
        #       case key
        #       when :given_name then :first_name
        #       when :family_name then :last_name
        #       else key
        #       end
        #     end
        #   end
        def transform_for_read(data)
          data
        end

        # Transform data for writing (hook for subclasses)
        #
        # Override to rename, convert, or filter attributes when writing.
        # Default implementation returns data unchanged.
        #
        # @param data [Hash] Hash from wizard (symbolized keys)
        # @return [Hash] Transformed hash (ready for model assignment)
        #
        # @example Rename fields back to database names
        #   def transform_for_write(data)
        #     data.transform_keys do |key|
        #       case key
        #       when :first_name then :given_name
        #       when :last_name then :family_name
        #       else key
        #       end
        #     end
        #   end
        def transform_for_write(data)
          data
        end
      end
    end
  end
end
