module Steps
  class WhichLeadProvider < DfE::Wizard::Step
    attribute :lead_provider_id, :integer

    validates :lead_provider_id, presence: true

    LeadProviderStub = Struct.new(:id, :name)

    def self.available_lead_providers
      [
        LeadProviderStub.new(1, 'Ambition Institute'),
        LeadProviderStub.new(2, 'Education Development Trust'),
        LeadProviderStub.new(3, 'Teach First'),
      ].freeze
    end

    def self.permitted_params
      %w[lead_provider_id]
    end
  end
end
