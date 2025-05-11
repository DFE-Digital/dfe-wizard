module Steps
  class RightToWorkOrStudy < DfE::Wizard::Step
    attr_accessor :right_to_work_or_study

    validates :right_to_work_or_study, presence: true

    def self.permitted_params
      %w[
        right_to_work_or_study
      ]
    end
  end
end
