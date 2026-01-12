module Steps
  module RegisterECT
    class LeadProviderStep
      include DfE::Wizard::Step

      attribute :lead_provider_id, :string

      validates :lead_provider_id, presence: true

      def self.permitted_params
        %w[lead_provider_id]
      end
    end
  end
end
