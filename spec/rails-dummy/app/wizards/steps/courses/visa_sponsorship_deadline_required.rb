module Steps
  module Courses
    class VisaSponsorshipDeadlineRequired
      include DfE::Wizard::Step

      attribute :visa_deadline_required, :boolean
      validates :visa_deadline_required, presence: true
    end
  end
end
