RSpec.describe AddCourseWizard do
  let(:wizard) do
    described_class.new(
      state_store: StateStores::AddCourse.new(repository:, provider:),
    )
  end

  let(:repository) do
    DfE::Wizard::Repository::WizardState.new(
      model: create(:wizard_state, key: 'add_course', state_key: SecureRandom.uuid),
    )
  end

  before { FeatureFlag.reset }

  describe 'when further education journey' do
    let(:provider) { double('Object', accredited?: true) }

    before do
      repository.write(level: 'Further education')
    end

    it 'from level to outcome' do
      wizard.current_step_name = :level
      expect(wizard).to have_next_step(:outcome)
    end

    it 'from outcome to funding type' do
      wizard.current_step_name = :outcome
      expect(wizard).to have_next_step(:funding_type)
    end

    it 'from funding type to full or part time' do
      wizard.current_step_name = :funding_type
      expect(wizard).to have_next_step(:full_or_part_time)
    end

    it 'from full or part time to school' do
      wizard.current_step_name = :full_or_part_time
      expect(wizard).to have_next_step(:school)
    end

    it 'from school to study site' do
      wizard.current_step_name = :school
      expect(wizard).to have_next_step(:study_site)
    end

    it 'from study site to applications open when feature flag is active' do
      FeatureFlag.activate(:applications_open)
      wizard.current_step_name = :study_site
      expect(wizard).to have_next_step(:applications_open)
    end

    it 'from study site to start date when feature flag is not active' do
      FeatureFlag.deactivate(:applications_open)
      wizard.current_step_name = :study_site
      expect(wizard).to have_next_step(:start_date)
    end

    it 'from applications_open to start date' do
      wizard.current_step_name = :applications_open
      expect(wizard).to have_next_step(:start_date)
    end

    it 'from start date to review' do
      wizard.current_step_name = :start_date
      expect(wizard).to have_next_step(:review)
    end

    it 'from review to courses list' do
      wizard.current_step_name = :review
      expect(wizard).to have_next_step(:courses_list)
    end

    it 'returns full theorical path on last steps' do
      wizard.current_step_name = :review
      expect(wizard).to have_flow_path(
        %i[
          level
          outcome
          funding_type
          full_or_part_time
          school
          study_site
          start_date
          review
        ],
      )
    end

    it 'returns full theorical path on last steps - applications open feature is on' do
      FeatureFlag.activate(:applications_open)
      wizard.current_step_name = :review
      expect(wizard).to have_flow_path(
        %i[
          level
          outcome
          funding_type
          full_or_part_time
          school
          study_site
          applications_open
          start_date
          review
        ],
      )
    end
  end

  describe 'when school direct' do
    describe 'when single accredited provider and fee based' do
      let(:provider) { double('Object', accredited?: true, accredited_partners: [double]) }

      it 'skip accredited provider step' do
        repository.write(funding_type: 'fee')
        wizard.current_step_name = :study_site
        expect(wizard).to have_next_step(:can_sponsor_student_visa)
      end
    end

    describe 'when single accredited provider and non fee based' do
      let(:provider) { double('Object', accredited?: true, accredited_partners: [double]) }

      it 'skip accredited provider step' do
        %w[salary apprenticeship].each do |funding_type|
          repository.write(funding_type:)
          wizard.current_step_name = :study_site
          expect(wizard).to have_next_step(:can_sponsor_skilled_worker_visa)
        end
      end
    end

    describe 'when multiple accredited providers' do
      let(:provider) { double('Object', accredited?: true, accredited_partners: [double, double]) }

      it 'goes to accredited provider step' do
        wizard.current_step_name = :study_site
        expect(wizard).to have_next_step(:accredited_provider)
      end
    end
  end
end
