module Steps
  class ImmigrationStatus
    include DfE::Wizard::Step

    attribute :status, :string
    attribute :other_status, :string

    validates :status, presence: true

    def self.permitted_params
      %w[
        status
        other_status
      ]
    end
  end
end
