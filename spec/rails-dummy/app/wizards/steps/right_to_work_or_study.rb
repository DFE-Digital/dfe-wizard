module Steps
  class RightToWorkOrStudy
    include DfE::Wizard::Step

    attribute :right_to_work_or_study, :string
    attribute :visa_expiry, :string
    attribute :visa_type, :string

    validates :right_to_work_or_study, presence: true

    def self.permitted_params
      %w[
        right_to_work_or_study
      ]
    end
  end
end
