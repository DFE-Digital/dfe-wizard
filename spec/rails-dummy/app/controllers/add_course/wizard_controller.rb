module AddCourse
  class WizardController < ApplicationController
    before_action :wizard

    def new; end

    def create
      if @wizard.save_current_step
        redirect_to @wizard.next_step_path
      else
        render :new
      end
    end

    def provider
      Provider.find_or_create_by(name: 'Provider A', code: 'ABC', recruitment_cycle_year: 2025)
    end

    def model
      WizardState.find_or_create_by(
        key: :add_course,
        state_key: params[:state_key],
        encrypted: true,
      )
    end

    def encryptor
      key = ActiveSupport::KeyGenerator.new('password').generate_key('1' * 32, 32)

      ActiveSupport::MessageEncryptor.new(key)
    end

    def repository
      @repository ||= DfE::Wizard::Repository::WizardState.new(model:, encryptor:)
    end

    def state_store
      @state_store ||= StateStores::AddCourse.new(repository:, provider:)
    end

    def wizard
      @wizard ||= AddCourseWizard.new(
        state_store:,
        current_step: params[:step],
        current_step_params: params,
      )
    end
  end
end
