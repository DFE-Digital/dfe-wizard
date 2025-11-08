module StateStores
  class PersonalInformation < DfE::Wizard::StateStore::InMemory
    attr_reader :application_form

    STEP_MAPPING = {
      name_and_date_of_birth: %i[first_name last_name date_of_birth],
      nationality: %i[nationalities],
      right_to_work_or_study: %i[right_to_work_or_study],
      immigration_status: %i[status other_status],
    }.freeze

    def initialize(application_form)
      super()
      @application_form = application_form
    end

    def read
      {
        steps: STEP_MAPPING.transform_values do |fields|
          fields.each_with_object({}) do |field, step_hash|
            value = application_form.public_send(field)
            step_hash[field] = value if value.present?
          end
        end,
      }
    end

    def write(updates)
      updates[:steps]&.each_value do |data|
        application_form.update!(data)
      end
    end
  end
end
