module StepOperations
  class CreateALevel
    attr_reader :step, :repository, :course

    def initialize(repository:, step:)
      @step = step
      @repository = repository
      @course = repository.record
    end

    def execute
      return { success: false, errors: @step.errors } if @step.invalid?

      if (existing_index = requirements.find_index { |r| r['uuid'] == step.uuid })
        requirements[existing_index] = requirement_hash
      else
        requirements << requirement_hash
      end

      course.a_level_subject_requirements = requirements
      course.save!

      { success: true }
    rescue StandardError => e
      { success: false, error: e.message }
    end

    private

    def requirements
      @requirements ||= course.a_level_subject_requirements || []
    end

    def requirement_hash
      {
        'uuid' => uuid,
        'subject' => step.subject,
        'minimum_grade_required' => step.minimum_grade_required,
        'other_subject' => step.other_subject,
      }.tap do |hash|
        hash.delete('other_subject') if step.subject != 'other_subject'
        hash.delete('minimum_grade_required') if step.minimum_grade_required.blank?
      end
    end

    def uuid
      step.uuid || SecureRandom.uuid
    end
  end
end
