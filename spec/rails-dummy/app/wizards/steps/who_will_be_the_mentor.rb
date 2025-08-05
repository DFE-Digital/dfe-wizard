require 'ostruct'

module Steps
  class WhoWillBeTheMentor < DfE::Wizard::Step
    attribute :mentor_id, :integer

    validates :mentor_id, presence: true

    MentorStub = Struct.new(:id, :teacher)
    TeacherStub = Struct.new(:full_name)

    def self.eligible_mentors
      [
        MentorStub.new(1, TeacherStub.new('Alice Mentor')),
        MentorStub.new(2, TeacherStub.new('Bob Mentor')),
      ].freeze
    end

    def self.permitted_params
      %w[mentor_id]
    end
  end
end
