module StateStores
  class ALevelsRequirements
    include DfE::Wizard::StateStore

    def any_a_levels?
      a_level_subject_requirements.size.positive?
    end

    def add_another_a_level?
      return false if maximum_number_of_a_level_subjects_reached?

      add_another_a_level == 'yes'
    end

    def has_remaining_a_levels?
      return true unless deletion_confirmed?

      a_level_subject_requirements.present?
    end

    def deletion_confirmed?
      confirmation == 'yes'
    end

    def maximum_number_of_a_level_subjects_reached?
      a_level_subject_requirements.size >= 4
    end

    def a_level_subject_requirements
      Array(read[:a_level_subject_requirements])
    end
  end
end
