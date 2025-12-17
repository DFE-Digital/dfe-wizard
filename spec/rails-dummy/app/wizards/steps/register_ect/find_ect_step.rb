module Steps
  module RegisterECT
    class FindECTStep
      include DfE::Wizard::Step

      attribute :trn, :string
      attribute :date_of_birth, :date

      validates :trn, presence: true
      validates :date_of_birth, presence: true

      def self.permitted_params
        %w[trn date_of_birth(1i) date_of_birth(2i) date_of_birth(3i)]
      end

      def assign_attributes(attrs = {})
        date_parts = attrs.symbolize_keys!.extract!(:'date_of_birth(1i)', :'date_of_birth(2i)', :'date_of_birth(3i)')

        super

        if date_parts.present? && date_parts.values.all?(&:present?)
          self.date_of_birth = Date.new(
            date_parts[:'date_of_birth(1i)'].to_i,
            date_parts[:'date_of_birth(2i)'].to_i,
            date_parts[:'date_of_birth(3i)'].to_i,
          )
        end
      rescue ArgumentError
        self.date_of_birth = nil
      end
    end
  end
end
