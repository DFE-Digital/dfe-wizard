module StateStores
  class PersonalInformation
    attr_reader :application_form

    def initialize(application_form)
      @application_form = application_form
    end

    def read
      {
        steps: {
          name_and_date_of_birth: {
            first_name: application_form.first_name,
            last_name: application_form.last_name,
            date_of_birth: application_form.date_of_birth,
          },
          nationality: {
            nationalities: application_form.nationalities.map(&:downcase),
            other_nationalities: application_form.other_nationalities,
          },
          right_to_work_or_study: {
            right_to_work_or_study: application_form.right_to_work_or_study,
          },
          immigration_status: {
            status: application_form.immigration_status,
          },
        },
      }
    end

    # args = { name_and_date_of_birth: => { first_name: 'Tomas', last_name: 'Stefano' } }
    #
    def write(args)
      @application_form.update!(args)
    end
  end
end
