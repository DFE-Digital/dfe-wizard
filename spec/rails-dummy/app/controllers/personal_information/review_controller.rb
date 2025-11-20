module PersonalInformation
  class ReviewController < WizardController
    def index
      @steps = @wizard.valid_steps
    end
  end
end
