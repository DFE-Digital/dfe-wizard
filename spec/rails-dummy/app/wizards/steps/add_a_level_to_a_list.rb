module Steps
  class AddALevelToAList
    include DfE::Wizard::Step

    MAXIMUM_NUMBER_OF_A_LEVEL_SUBJECTS = 4

    attribute :add_another_a_level
    attribute :subjects, default: []

    validates :add_another_a_level,
              presence: true,
              unless: :maximum_number_of_a_level_subjects?

    def maximum_number_of_a_level_subjects?
      subjects.size >= MAXIMUM_NUMBER_OF_A_LEVEL_SUBJECTS
    end
  end
end
