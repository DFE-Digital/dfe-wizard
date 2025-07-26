# frozen_string_literal: true

module DfE
  module Wizard
    class Step
      include ActiveModel::Model
      include ActiveModel::Attributes
      attr_accessor :wizard

      delegate :store, :url_helpers, to: :wizard

      def initialize(step_attributes = {})
        super

        @step_attributes = step_attributes.except(:wizard)
      end

      def serializable_data
        if attributes.blank?
          ActiveSupport.deprecator.warn(
            '[Wizard::Step] Falling back to legacy `@step_attributes` serialization. ' \
            'To fix, either use `ActiveModel::Attributes` (included already on DfE::Wizard::Step).' \
            'Or define `#serializable_data` manually in your Step class. ', \
          )

          @step_attributes.keys.each_with_object({}) do |key, hash|
            hash[key.to_sym] = public_send(key)
          end
        else
          attributes
        end
      end

      def self.model_name
        original_i18n_key = super.i18n_key
        model_name = ActiveModel::Name.new(self, nil, formatted_name.demodulize)
        model_name.i18n_key = original_i18n_key
        model_name
      end

      # @deprecated
      def self.formatted_name
        name.sub(/::Step\z/, '').sub('Step', '')
      end

      # @deprecated
      def self.route_name
        formatted_name.underscore.gsub('/', '_')
      end

      def self.permitted_params
        raise NotImplementedError
      end

      # @deprecated
      def step_name
        self.class.model_name.name
      end

      # @deprecated
      def previous_step
        raise NotImplementedError
      end

      # @deprecated
      def next_step
        raise NotImplementedError
      end

      # @deprecated
      def next_edit_step_path(next_step_klass)
        url_helpers.public_send("edit_#{next_step_klass.route_name}_path", next_step_path_arguments)
      end

      # @deprecated
      def next_step_path(next_step_klass)
        url_helpers.public_send("#{next_route_name(next_step_klass)}_path", next_step_path_arguments)
      end

      # @deprecated
      def previous_step_path(previous_step_klass)
        url_helpers.public_send("#{previous_route_name(previous_step_klass)}_path", previous_step_path_arguments)
      end

      # @deprecated
      def next_step_path_arguments
        wizard.default_path_arguments if wizard.respond_to?(:default_path_arguments)
      end

      # @deprecated
      def previous_step_path_arguments
        wizard.default_path_arguments if wizard.respond_to?(:default_path_arguments)
      end

      # @deprecated
      def previous_route_name(previous_step_klass)
        [wizard.default_path_prefix, previous_step_klass.route_name].compact.join('_')
      end

      # @deprecated
      def next_route_name(next_step_klass)
        [wizard.default_path_prefix, next_step_klass.route_name].compact.join('_')
      end
    end
  end
end
