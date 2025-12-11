module StateStores
  class ALevelsRequirements
    include DfE::Wizard::StateStore

    def any_a_levels?
      a_level_subject_requirements.size.positive?
    end

    def has_remaining_a_levels?
      return true unless deletion_confirmed?

      a_level_subject_requirements.present?
    end

    def add_another_a_level?
      add_another_a_level == 'yes' && !maximum_number_of_a_level_subjects_reached?
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

    def provider_code
      course.provider_code
    end

    def course_code
      course.course_code
    end

    def recruitment_cycle_year
      course.recruitment_cycle_year
    end

    def course
      repository.record
    end
  end
end
