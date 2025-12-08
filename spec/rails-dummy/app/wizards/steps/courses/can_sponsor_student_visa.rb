module Steps
  module Courses
    class CanSponsorStudentVisa
      include DfE::Wizard::Step

      attribute :can_sponsor_student_visa, :boolean
      validates :can_sponsor_student_visa, presence: true
    end
  end
end
