module Steps
  class CanReceiveMentorTraining < DfE::Wizard::Step
    attribute :mentor_id, :integer
    attribute :lp_will_provide, :string

    def self.permitted_params
      %w[mentor_id lp_will_provide]
    end

    def mentor
      Steps::WhoWillBeTheMentor.eligible_mentors.find { |mentor| mentor.id == mentor_id.to_i }
    end
  end
end
