class WizardsController < ApplicationController
  def index
    @wizards = [
      WizardInfo.new(
        klass: PersonalInformationWizard,
        namespace: 'personal_information',
        name: 'Personal Information Wizard',
        start_path: :name_and_date_of_birth
      ),
      WizardInfo.new(
        klass: GetFundingWizard,
        namespace: 'get_funding',
        name: 'Get Funding Wizard',
        start_path: :personal_details
      )
    ]
  end
end
