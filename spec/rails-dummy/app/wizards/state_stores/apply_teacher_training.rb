module StateStores
  class ApplyTeacherTraining
    include DfE::Wizard::StateStore

    def know_the_course_to_apply?
      know_the_course_to_apply == 'yes'
    end

    def completed?; end

    def reapplication_limit_reached?; end

    def duplicate_course?; end

    def course_closed?; end

    def course_unavailable?; end

    def multiple_study_modes?; end

    def multiple_schools?; end
  end
end
