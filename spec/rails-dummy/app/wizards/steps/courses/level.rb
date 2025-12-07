module Steps
  module Courses
    class Level
      include DfE::Wizard::Step

      attribute :level, :string

      validates :level, presence: true
    end
  end
end
