module Steps
  class CanReceiveMentorTraining
    include DfE::Wizard::Step

    attribute :lp_will_provide, :string

    def self.permitted_params
      %w[mentor_id lp_will_provide]
    end
  end
end
