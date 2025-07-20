module StateStores
  class GetFundingWizardStore
    attr_reader :application_form

    def initialize(application_form)
      @application_form = application_form
    end

    def read
      {
        steps: {
          personal_details: {
            first_name: application_form.first_name,
            last_name: application_form.last_name,
            date_of_birth: application_form.date_of_birth,
          },
          academic_background: {
            highest_qualification: application_form.highest_qualification,
            institution_name: application_form.institution_name,
            needs_funding: application_form.needs_funding,
          },
          get_funding: {
            funding_type: application_form.funding_type,
            amount_requested: application_form.amount_requested,
            complete: application_form.funding_section_complete,
          },
          visa_requirement: {
            has_visa: application_form.has_visa,
            needs_support: application_form.needs_support,
          },
          additional_support: {
            requires_accessibility: application_form.requires_accessibility,
            support_notes: application_form.support_notes,
          }
        }
      }
    end

    def write(data)
      step_data = data[:steps] || data

      step_data.each do |step, attributes|
        case step.to_sym
        when :personal_details
          application_form.assign_attributes(attributes.slice(:first_name, :last_name, :date_of_birth))
        when :academic_background
          application_form.assign_attributes(attributes.slice(
            :highest_qualification, :institution_name, :needs_funding
          ))
        when :get_funding
          application_form.assign_attributes(attributes.slice(
            :funding_type, :amount_requested, :complete
          ).transform_keys do |key|
            key == :complete ? :funding_section_complete : key
          end)
        when :visa_requirement
          application_form.assign_attributes(attributes.slice(:has_visa, :needs_support))
        when :additional_support
          application_form.assign_attributes(attributes.slice(:requires_accessibility, :support_notes))
        end
      end

      application_form.save!
    end
  end
end
