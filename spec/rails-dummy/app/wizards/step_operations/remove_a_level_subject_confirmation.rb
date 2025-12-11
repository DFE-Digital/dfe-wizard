module StepOperations
  class RemoveALevelSubjectConfirmation
    def initialize(repository:, step:)
      @repository = repository
      @step = step
      @course = repository.record
    end

    def execute
      return { success: false, errors: @step.errors } if @step.invalid?
      return { success: false } unless @step.deletion_confirmed?

      a_level_subject_requirements = @course.a_level_subject_requirements.reject do |requirement|
        requirement['uuid'] == @step.uuid
      end

      if a_level_subject_requirements.present?
        @course.update!(a_level_subject_requirements:)
      else
        @course.update!(
          a_level_subject_requirements: [],
          accept_pending_a_level: nil,
          accept_a_level_equivalency: nil,
          additional_a_level_equivalencies: nil,
        )
      end

      { success: true }
    end
  end
end
