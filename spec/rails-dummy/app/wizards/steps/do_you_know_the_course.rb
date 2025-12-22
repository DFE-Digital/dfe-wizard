module Steps
  class DoYouKnowTheCourse
    include DfE::Wizard::Step

    attribute :know_the_course_to_apply, :string
    validates :know_the_course_to_apply, presence: true

    def self.permitted_params
      [:know_the_course_to_apply]
    end
  end
end
