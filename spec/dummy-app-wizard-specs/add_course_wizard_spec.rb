RSpec.describe AddCourseWizard do
  let(:wizard) do
    described_class.new(state_store:)
  end

  let(:state_store) do
    StateStores::AddCourse.new(repository:, provider:)
  end

  let(:repository) do
    DfE::Wizard::Repository::WizardState.new(
      model: create(:wizard_state, key: 'add_course', state_key: SecureRandom.uuid),
    )
  end

  before { FeatureFlag.reset }

  shared_examples_for 'specialism steps' do
    context 'when design technology subject' do
      it 'from subjects to design_technology step' do
        wizard.current_step_name = :subjects
        state_store.write(main_subject: 'Design and technology')
        expect(wizard).to have_next_step(:design_technology)
      end
    end

    context 'when modern languages subject' do
      it 'from subjects to modern language step' do
        wizard.current_step_name = :subjects
        state_store.write(main_subject: 'Modern languages')
        expect(wizard).to have_next_step(:modern_languages)
      end
    end

    context 'when engineer teach physics subject' do
      it 'from subjects to modern language step' do
        wizard.current_step_name = :subjects
        state_store.write(main_subject: 'Physics')
        expect(wizard).to have_next_step(:engineers_teach_physics)
      end
    end
  end

  shared_examples_for 'direct steps' do
    it 'from age range to outcome step' do
      wizard.current_step_name = :age_range
      expect(wizard).to have_next_step(:outcome)
    end

    it 'from outcome to funding type step' do
      wizard.current_step_name = :outcome
      expect(wizard).to have_next_step(:funding_type)
    end

    it 'from full_or_part_time to school step' do
      wizard.current_step_name = :full_or_part_time
      expect(wizard).to have_next_step(:school)
    end

    it 'from school to study site step' do
      wizard.current_step_name = :school
      expect(wizard).to have_next_step(:study_site)
    end

    it 'from application open to start date step' do
      wizard.current_step_name = :applications_open
      expect(wizard).to have_next_step(:start_date)
    end

    it 'from start date open to review step' do
      wizard.current_step_name = :start_date
      expect(wizard).to have_next_step(:review)
    end

    it 'from review to courses list' do
      wizard.current_step_name = :review
      expect(wizard).to have_next_step(:courses_list)
    end
  end

  shared_examples 'visa deadline steps' do
    context 'can_sponsor_skilled_worker_visa' do
      before { wizard.current_step_name = :can_sponsor_skilled_worker_visa }

      context 'wnen visa sponsorship' do
        before { state_store.write(can_sponsor_skilled_worker_visa: true) }

        it 'goes to visa_sponsorship_application_deadline_required' do
          expect(wizard).to have_next_step(:visa_sponsorship_application_deadline_required)
        end
      end

      context 'wnen no visa sponsorship' do
        before { state_store.write(can_sponsor_skilled_worker_visa: false) }

        it 'when applications_open feature is active goes to visa_sponsorship_application_deadline_required' do
          FeatureFlag.activate(:applications_open)
          expect(wizard).to have_next_step(:applications_open)
        end

        it 'when applications_open feature is not active goes to visa_sponsorship_application_deadline_required' do
          FeatureFlag.deactivate(:applications_open)
          expect(wizard).to have_next_step(:start_date)
        end
      end
    end

    context 'can_sponsor_student_visa' do
      before { wizard.current_step_name = :can_sponsor_student_visa }

      context 'wnen visa sponsorship' do
        before { state_store.write(can_sponsor_student_visa: true) }

        it 'goes to visa_sponsorship_application_deadline_required' do
          expect(wizard).to have_next_step(:visa_sponsorship_application_deadline_required)
        end
      end

      context 'wnen no visa sponsorship' do
        before { state_store.write(can_sponsor_student_visa: false) }

        it 'when applications_open feature is active goes to visa_sponsorship_application_deadline_required' do
          FeatureFlag.activate(:applications_open)
          expect(wizard).to have_next_step(:applications_open)
        end

        it 'when applications_open feature is not active goes to visa_sponsorship_application_deadline_required' do
          FeatureFlag.deactivate(:applications_open)
          expect(wizard).to have_next_step(:start_date)
        end
      end
    end

    context 'visa_sponsorship_application_deadline_required' do
      before { wizard.current_step_name = :visa_sponsorship_application_deadline_required }

      context 'wnen visa sponsorship deadline' do
        before { state_store.write(visa_deadline_required: true) }

        it 'goes to visa_sponsorship_application_deadline_required' do
          expect(wizard).to have_next_step(:visa_sponsorship_application_deadline_at)
        end
      end

      context 'wnen no visa sponsorship' do
        before { state_store.write(visa_deadline_required: false) }

        it 'when applications_open feature is active goes to visa_sponsorship_application_deadline_required' do
          FeatureFlag.activate(:applications_open)
          expect(wizard).to have_next_step(:applications_open)
        end

        it 'when applications_open feature is not active goes to visa_sponsorship_application_deadline_required' do
          FeatureFlag.deactivate(:applications_open)
          expect(wizard).to have_next_step(:start_date)
        end
      end
    end
  end

  describe 'when further education journey' do
    let(:provider) { double('Object', accredited?: false) }

    before do
      state_store.write(level: 'Further education')
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
    let(:provider) { double('Object', accredited?: false, accredited_partners: [double]) }

    include_examples 'specialism steps'
    include_examples 'direct steps'
    include_examples 'visa deadline steps'

    describe 'when single accredited provider and fee based' do
      let(:provider) { double('Object', accredited?: false, accredited_partners: [double]) }

      it 'skip accredited provider step' do
        state_store.write(funding_type: 'fee')
        wizard.current_step_name = :study_site
        expect(wizard).to have_next_step(:can_sponsor_student_visa)

        expect(wizard).to have_flow_path(
          %i[
            level
            subjects
            age_range
            outcome
            funding_type
            full_or_part_time
            school
            study_site
          ],
        )
      end
    end

    describe 'when single accredited provider' do
      let(:provider) { double('Object', accredited?: false, accredited_partners: [double]) }

      it 'skip accredited provider step' do
        %w[salary apprenticeship].each do |funding_type|
          state_store.write(funding_type:)
          wizard.current_step_name = :study_site
          expect(wizard).to have_next_step(:can_sponsor_skilled_worker_visa)
          expect(wizard).to have_flow_path(
            %i[
              level
              subjects
              age_range
              outcome
              funding_type
              full_or_part_time
              school
              study_site
            ],
          )
        end
      end
    end

    describe 'when multiple accredited providers' do
      let(:provider) { double('Object', accredited?: false, accredited_partners: [double, double]) }

      it 'goes to accredited provider step' do
        wizard.current_step_name = :study_site
        expect(wizard).to have_next_step(:accredited_provider)
        expect(wizard).to have_flow_path(
          %i[
            level
            subjects
            age_range
            outcome
            funding_type
            full_or_part_time
            school
            study_site
          ],
        )
      end
    end
  end

  describe 'when university' do
    let(:provider) { double('Object', accredited?: true, accredited_partners: [double, double]) }
    include_examples 'specialism steps'
    include_examples 'direct steps'
    include_examples 'visa deadline steps'

    it 'skip accredited provider step even' do
      wizard.current_step_name = :study_site
      expect(wizard).to have_next_step(:can_sponsor_skilled_worker_visa)
    end
  end

  describe 'when school direct and  teacher degree apprenticeship' do
    let(:provider) { double('Object', accredited?: false, accredited_partners: [double, double]) }
    include_examples 'specialism steps'

    before { state_store.write(qualification: 'undergraduate_degree_with_qts') }

    it 'returns whole flow' do
      wizard.current_step_name = :review

      expect(wizard).to have_flow_path(
        %i[
          level
          subjects
          age_range
          outcome
          school
          study_site
          accredited_provider
          start_date
          review
        ],
      )
    end

    context 'when single accredited provider' do
      let(:provider) { double('Object', accredited?: false, accredited_partners: [double]) }

      it 'returns the whole flow' do
        wizard.current_step_name = :review
        expect(wizard).to have_flow_path(
          %i[
            level
            subjects
            age_range
            outcome
            school
            study_site
            start_date
            review
          ],
        )
      end
    end
  end

  describe 'when university and teacher degree apprenticeship' do
    let(:provider) { double('Object', accredited?: true, accredited_partners: [double, double]) }
    include_examples 'specialism steps'

    before { state_store.write(qualification: 'undergraduate_degree_with_qts') }

    it 'returns whole flow' do
      wizard.current_step_name = :review

      expect(wizard).to have_flow_path(
        %i[
          level
          subjects
          age_range
          outcome
          school
          study_site
          start_date
          review
        ],
      )
    end
  end
end
