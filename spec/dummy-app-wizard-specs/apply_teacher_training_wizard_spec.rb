RSpec.describe ApplyTeacherTrainingWizard do
  subject(:wizard) { described_class.new(state_store:) }

  let(:state_store) do
    StateStores::ApplyTeacherTraining.new(current_application_form:, application_choice:)
  end

  let(:current_application_form) { create(:application_form) }
  let(:application_choice) { nil }

  describe 'step operators' do
    it 'returns all step operations' do
      expect(wizard).to have_step_operations(
        course_selection: [
          DfE::Wizard::Operations::Validate,
          StepOperations::CreateApplicationChoice,
        ],
        study_mode: [
          DfE::Wizard::Operations::Validate,
          StepOperations::UpdateApplicationChoiceStudyMode,
        ],
        school_selection: [
          DfE::Wizard::Operations::Validate,
          StepOperations::UpdateApplicationChoiceSchool,
        ],
        confirm_apply: [
          StepOperations::SubmitApplicationChoice,
        ],
      )
    end
  end

  describe '#root_step' do
    it 'do_you_know_the_course step' do
      expect(wizard).to have_root_step(:do_you_know_the_course)
    end
  end

  describe 'flow' do
    context 'when user knows the course to apply' do
      it 'next step as provider_selection step' do
        expect(wizard).to branch_from(:do_you_know_the_course)
          .to(:provider_selection)
          .when(know_the_course_to_apply: 'yes')
      end
    end

    context 'when user does not know the course to apply' do
      it 'next step as provider_selection step' do
        expect(wizard).to branch_from(:do_you_know_the_course)
          .to(:go_to_find_explanation)
          .when(know_the_course_to_apply: 'no')
      end
    end

    context 'when go_to_find_explanation step' do
      it 'exit page' do
        wizard.current_step_name = :go_to_find_explanation
        expect(wizard.next_step).to be nil
      end
    end

    context 'when provider selection' do
      it 'goes to course selection' do
        wizard.current_step_name = :provider_selection
        expect(wizard).to have_next_step(:course_selection)
      end
    end

    context 'when course selection' do
      let(:course) { create(:course) }
      let(:provider) { create(:provider) }

      context 'when course has multiple study modes' do
        let(:course) { create(:course, :with_multiple_study_modes) }

        it 'next step as study mode selection' do
          expect(wizard).to branch_from(:course_selection).to(:study_mode_selection).when(
            course_id: course.id,
            provider_id: provider.id,
          )
        end
      end

      context 'when course has multiple schools' do
        it 'next step as school selection' do
          expect(wizard).to branch_from(:course_selection).to(:school_selection)
        end
      end

      context 'when course has multiple sites and provider school is not selectable' do
        it 'next step is review' do
          expect(wizard).to branch_from(:course_selection).to(:review)
        end
      end

      context 'when course has no course availability' do
        it 'next step is full course selection' do
          expect(wizard).to branch_from(:course_selection).to(:full_course_selection)
        end
      end

      context 'when course has single site and single study mode' do
        it 'next step is review' do
          expect(wizard).to branch_from(:course_selection).to(:review)
        end
      end

      context 'when choice exists on application form' do
        it 'next step is duplicate course selection' do
          expect(wizard).to branch_from(:course_selection).to(:duplicate_course_selection)
        end
      end

      context 'when editing the course choice and choosing the same course' do
        it 'returns review' do
          expect(wizard).to branch_from(:course_selection).to(:review)
        end
      end

      context 'when editing the second course choice and choosing the first course choice' do
        it 'next step is duplicate course selection' do
          expect(wizard).to branch_from(:course_selection).to(:duplicate_course_selection)
        end
      end

      context 'when course choice has no availability' do
        it 'next step is full course selection' do
          expect(wizard).to branch_from(:course_selection).to(:full_course_selection)
        end
      end

      context 'when candidate reach application limit' do
        it 'next step is reach reapplication limit' do
          expect(wizard).to branch_from(:course_selection).to(:reached_reapplication_limit)
        end
      end

      context 'when course is closed' do
        it 'next step is closed course' do
          expect(wizard).to branch_from(:course_selection).to(:closed_course_selection)
        end
      end
    end

    context 'when on study mode step' do
      context 'when couse has only one school' do
        it 'next step is review' do
          expect(wizard).to branch_from(:study_mode_selection).to(:review)
        end
      end

      context 'when course has many schools' do
        it 'next step is review' do
          expect(wizard).to branch_from(:study_mode_selection).to(:school_selection)
        end
      end

      context 'when course has many schools but provider chosen to candidate not select a school' do
        it 'next step is review' do
          expect(wizard).to branch_from(:study_mode_selection).to(:review)
        end
      end
    end
  end

  context 'when on school selection step' do
    it 'next step is review' do
      expect(wizard).to branch_from(:school_selection).to(:review)
    end
  end
  context 'when on review step' do
    it 'next step is confirm apply' do
      expect(wizard).to branch_from(:review).to(:confirm_apply)
    end
  end

  context 'when on confirm apply step' do
    it 'next step is application choices list' do
      expect(wizard).to branch_from(:confirm_apply).to(:application_choices_list)
    end
  end
end
