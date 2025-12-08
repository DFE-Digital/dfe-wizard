module Steps
  module Courses
    class Subjects
      include DfE::Wizard::Step

      attribute :main_subject, :string
      validates :main_subject, presence: true
    end
  end
end
