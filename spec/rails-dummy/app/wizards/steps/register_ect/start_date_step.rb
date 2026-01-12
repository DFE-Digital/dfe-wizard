module Steps
  module RegisterECT
    class StartDateStep
      include DfE::Wizard::Step

      attribute :start_date, :date

      validates :start_date, presence: true

      def self.permitted_params
        %w[start_date(1i) start_date(2i) start_date(3i)]
      end

      def assign_attributes(attrs = {})
        date_parts = attrs.symbolize_keys!.extract!(:'start_date(1i)', :'start_date(2i)', :'start_date(3i)')

        super

        if date_parts.present? && date_parts.values.all?(&:present?)
          self.start_date = Date.new(
            date_parts[:'start_date(1i)'].to_i,
            date_parts[:'start_date(2i)'].to_i,
            date_parts[:'start_date(3i)'].to_i,
          )
        end
      rescue ArgumentError
        self.start_date = nil
      end
    end
  end
end
