module PersonalInformation
  class WizardController < ApplicationController
    before_action :assign_wizard

    def new; end

    def create
      if @wizard.valid_step?
        @wizard.save

        redirect_to @wizard.next_step_path
      else
        render :new
      end
    end

    def assign_wizard
      state_store = StateStores::PersonalInformation.new(
          session:,
          key: 'personal_information',
      )

      @wizard = PersonalInformationWizard.new(
        current_step:,
        state_store:,
        step_params: params,
      )
    end

    def current_step
      controller_name.to_sym
    end
  end
end
