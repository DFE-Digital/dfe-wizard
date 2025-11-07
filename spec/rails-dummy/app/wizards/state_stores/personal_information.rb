module StateStores
  class PersonalInformation < DfE::Wizard::StateStore::Base
    attr_reader :application_form

    def initialize(application_form)
      @application_form = application_form
      @state_key = SecureRandom.uuid
    end

    def read
      JSON.parse(application_form.wizard_state || '{}')
    end

    def write(updates)
      current = read
      application_form.wizard_state = current.deep_merge(updates).to_json
    end

    def clear
      application_form.wizard_state = '{}'
    end

    def state_key
      @state_key
    end
  end
end
