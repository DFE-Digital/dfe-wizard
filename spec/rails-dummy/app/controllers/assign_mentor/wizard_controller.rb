module AssignMentor
  class WizardController < ApplicationController
    before_action :assign_wizard
    before_action :verify_step_access

    def new = nil

    def create
      if @wizard.valid_step?
        @wizard.save
        redirect_to @wizard.next_step_path
      else
        render :new
      end
    end

    private

    def verify_step_access
      render status: :not_found, formats: [:html], template: 'errors/not_found' unless @wizard.current_step_accessible?
    end

    def assign_wizard
      @wizard = AssignMentorWizard.new(
        current_step: current_step,
        state_store: StateStores::SessionStore.new(session, 'assign_mentor'),
        step_params: params,
      )
    end

    def current_step
      controller_name.to_sym
    end
  end
end
