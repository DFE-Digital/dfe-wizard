module Steps
  module Courses
    class FundingType
      include DfE::Wizard::Step

      attribute :funding_type, :string
      validates :funding_type, presence: true
    end
  end
end
