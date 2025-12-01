module AssignMentor
  class WizardController < ApplicationController
    before_action :assign_wizard
    before_action :verify_step_access

    def new = nil

    def create
      if @wizard.save_current_step
        redirect_to @wizard.next_step_path
      else
        render :new
      end
    end

    private

    def verify_step_access
      unless @wizard.valid_path_to_current_step?
        render status: :not_found, formats: [:html],
               template: 'errors/not_found'
      end
    end

    def assign_wizard
      state_store = StateStores::AssignMentor.new(
        repository: DfE::Wizard::Repository::Session.new(session:, key: :assign_mentor_wizard),
      )

      @wizard = AssignMentorWizard.new(
        current_step: current_step,
        current_step_params: params,
        state_store:,
      )
    end

    def current_step
      controller_name.to_sym
    end
  end
end
