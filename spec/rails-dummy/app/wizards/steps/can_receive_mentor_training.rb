module Steps
  class CanReceiveMentorTraining < DfE::Wizard::Step
    attribute :mentor_id, :integer

    def self.permitted_params
      %w[mentor_id]
    end

    def mentor
      Steps::WhoWillBeTheMentor.eligible_mentors.find { |mentor| mentor.id == mentor_id.to_i }
    end
  end
end
