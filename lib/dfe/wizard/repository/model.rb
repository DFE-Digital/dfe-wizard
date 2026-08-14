module DfE
  module Wizard
    module Repository
      class Model < Base
        attr_reader :record

        def initialize(record:, encrypted: false, encryptor: nil)
          raise ArgumentError, 'record cannot be nil' if record.nil?

          @record = record

          super(encrypted:, encryptor:)
        end

        def readable_attributes
          @record.class.column_names.map(&:to_sym) - excluded_columns
        end

        def writable_attributes
          readable_attributes
        end

        def excluded_columns
          []
        end

        def clear
          raise NotImplementedError,
                'Model repository does not support clear operation. ' \
                'Clearing a model record could violate business rules and validations. ' \
                'If you need to clear data, you need to create a subclass and implement #clear.'
        end

        def read_data
          readable_attributes.to_h { |attr| [attr, @record.public_send(attr)] }
        end

        def write_data(hash)
          assignable = hash.select { |key, _| writable_attribute?(key) }
          @record.assign_attributes(assignable)
          @record.save!
        end

        def delete_data
          raise NotImplementedError, 'Model repository does not support delete'
        end

        def transform_for_read(data)
          data.deep_symbolize_keys
        end

        def transform_for_write(data)
          data.deep_symbolize_keys
        end

        private

        def writable_attribute?(attr)
          writable_attributes.include?(attr) && @record.respond_to?("#{attr}=")
        end
      end
    end
  end
end
