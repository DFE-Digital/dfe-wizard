module Steps
  module Courses
    class Outcome
      include DfE::Wizard::Step

      attribute :qualification, :string
      validates :qualification, presence: true
    end
  end
end
