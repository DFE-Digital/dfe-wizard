module Steps
  module RegisterECT
    class NationalInsuranceNumberStep
      include DfE::Wizard::Step

      attribute :national_insurance_number, :string

      validates :national_insurance_number, presence: true

      def self.permitted_params
        %w[national_insurance_number]
      end
    end
  end
end
