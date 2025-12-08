module Steps
  module Courses
    class CanSponsorSkilledWorkerVisa
      include DfE::Wizard::Step

      attribute :can_sponsor_skilled_worker_visa, :boolean
      validates :can_sponsor_skilled_worker_visa, presence: true
    end
  end
end
