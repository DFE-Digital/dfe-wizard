module PersonalInformation
  class WizardController < ApplicationController
    before_action :assign_wizard

    def new; end

    def create
      if @wizard.save_current_step
        redirect_to @wizard.next_step_path
      else
        render :new
      end
    end

    def assign_wizard
      state_store = StateStores::PersonalInformation.new(
        repository: DfE::Wizard::Repository::Session.new(session:, key: :personal_information),
      )

      @wizard = PersonalInformationWizard.new(
        current_step:,
        current_step_params: params,
        state_store:,
      )
    end

    def current_step
      controller_name.to_sym
    end
  end
end
