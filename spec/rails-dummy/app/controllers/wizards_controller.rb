class WizardsController < ApplicationController
  def index
    @wizards = [
      WizardInfo.new(
        klass: PersonalInformationWizard,
        namespace: 'personal_information',
        name: 'Personal Information Wizard',
        start_path: :name_and_date_of_birth,
      ),
      WizardInfo.new(
        klass: GetFundingWizard,
        namespace: 'get_funding',
        name: 'Get Funding Wizard',
        start_path: :personal_details,
      ),
      WizardInfo.new(
        klass: AssignMentorWizard,
        namespace: 'assign_mentor',
        name: 'Assign Mentor Wizard',
        start_path: :who_will_be_the_mentor,
      ),
    ]
  end
end
