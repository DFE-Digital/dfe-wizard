module Repositories
  class ALevelsRequirements < DfE::Wizard::Repository::Model
    def transform_for_read(data)
      data.merge(
        a_level_subject_requirements: data[:a_level_subject_requirements] || [],
      )
    end

    def transform_for_write(data)
      transformed = data.dup

      if data[:subject].present?
        new_requirement = {
          uuid: data[:uuid] || SecureRandom.uuid,
          subject: data[:subject],
          other_subject: data[:other_subject],
          minimum_grade_required: data[:minimum_grade_required],
        }.compact

        requirements = record.a_level_subject_requirements || []
        existing_index = requirements.find_index { |req| req['uuid'] == new_requirement[:uuid] }

        if existing_index
          requirements[existing_index] = new_requirement
        else
          requirements << new_requirement
        end

        transformed[:a_level_subject_requirements] = requirements
      end

      transformed
    end
  end
end
