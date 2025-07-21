module PersonalInformation
  class ReviewController < WizardController
    def index
      @summary_steps = @wizard.summary_steps
    end
  end
end
