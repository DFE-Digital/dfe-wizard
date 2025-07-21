module Steps
  class RightToWorkOrStudy < DfE::Wizard::Step
    attribute :right_to_work_or_study, :string

    validates :right_to_work_or_study, presence: true

    def self.permitted_params
      %w[
        right_to_work_or_study
      ]
    end
  end
end
