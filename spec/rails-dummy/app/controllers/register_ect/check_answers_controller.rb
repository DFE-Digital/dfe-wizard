module RegisterECT
  class CheckAnswersController < WizardController
    def new
      @review = RegisterECTReview.new(@wizard)
    end
  end
end
