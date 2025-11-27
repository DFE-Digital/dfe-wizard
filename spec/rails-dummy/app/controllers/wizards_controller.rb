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
        klass: AssignMentorWizard,
        namespace: 'assign_mentor',
        name: 'Assign Mentor Wizard',
        start_path: :who_will_be_the_mentor,
      ),
      WizardInfo.new(
        klass: RegisterECTWizard,
        namespace: 'register_ect',
        name: 'Register ECT Wizard',
        start_path: :find_ect,
      ),
    ]
  end
end
