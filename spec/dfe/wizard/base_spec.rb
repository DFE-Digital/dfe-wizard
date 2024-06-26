require 'spec_helper'
require 'action_controller'
require 'rails'

RSpec.describe DfE::Wizard::Base do
  subject(:wizard) do
    TestWizard::MyAwesomeCourseSelectionWizard.new(current_step:, step_params: params)
  end

  let(:current_step) { nil }
  let(:params) { ActionController::Parameters.new(step_params) }
  let(:step_params) { {} }
  let(:my_awesome_course_selection_wizard_steps) do
    [
      {
        test_do_you_know_which_course: TestWizard::TestDoYouKnowWhichCourse,
        test_go_to_find: TestWizard::TestGoToFindStep,
        test_provider_selection: TestWizard::TestProviderSelection,
        test_course_name_selection: TestWizard::TestCourseNameSelection,
        test_course_study_mode_selection: TestWizard::TestCourseStudyModeSelection,
        test_course_site_selection: TestWizard::TestCourseSiteSelection,
        test_find_selection: TestWizard::TestFindSelection,
        test_review: TestWizard::TestReview,
      },
    ]
  end
  let(:application) { double('application') }
  let(:routes) { double('routes') }
  let(:url_helpers) { double('url_helpers') }

  before do
    allow(Rails).to receive(:application).and_return(application)
    allow(application).to receive(:routes).and_return(routes)
    allow(routes).to receive(:url_helpers).and_return(url_helpers)
  end

  describe '.steps' do
    it 'returns the steps declared in the block' do
      expect(
        TestWizard::MyAwesomeCourseSelectionWizard.steps,
      ).to eq(my_awesome_course_selection_wizard_steps)
    end
  end

  describe '#steps' do
    it 'pass the steps to the instance' do
      expect(wizard.steps).to eq(my_awesome_course_selection_wizard_steps)
    end
  end

  describe '#current_step' do
    context 'when there is no current step' do
      let(:current_step) { nil }

      it 'returns nil' do
        expect(wizard.current_step).to be_nil
      end
    end

    context 'when there is current step' do
      let(:current_step) { :test_go_to_find }

      it 'returns the instance of the current step' do
        expect(wizard.current_step).to be_instance_of(TestWizard::TestGoToFindStep)
      end
    end

    context 'when not to log' do
      let(:logger) { wizard.logger }
      subject(:wizard) { TestWizard::AnotherWizard.new(current_step: :test_another_wizard_first) }

      it 'do not log' do
        allow(logger).to receive(:info)
        allow(wizard).to receive(:log_condition?).and_return(false)
        wizard.current_step
        expect(logger).not_to have_received(:info)
      end
    end

    context 'when log' do
      let(:logger) { wizard.logger }
      let(:current_step) { :test_go_to_find }

      it 'do log' do
        allow(logger).to receive(:info)
        allow(wizard).to receive(:log_condition?).and_return(true)
        wizard.current_step
        expect(logger).to have_received(:info)
      end
    end
  end

  describe '#current_step_name' do
    context 'when there is no current step' do
      let(:current_step) { nil }

      it 'returns nil' do
        expect(wizard.current_step_name).to be_nil
      end
    end

    context 'when there is current step' do
      let(:current_step) { :test_go_to_find }

      it 'returns the instance of the current step' do
        expect(wizard.current_step_name).to be(:test_go_to_find)
      end
    end
  end

  describe '#step_params' do
    let(:current_step) { :test_do_you_know_which_course }
    let(:step_params) do
      { test_do_you_know_which_course: { answer: 'yes' } }
    end

    it 'assigns attributes to the current step' do
      expect(wizard.current_step.answer).to eq('yes')
    end
  end

  describe '#next_step' do
    let(:current_step) { :test_do_you_know_which_course }

    context 'when answer go to one page' do
      let(:step_params) do
        { test_do_you_know_which_course: { answer: 'yes' } }
      end

      it 'assigns attributes to the current step' do
        expect(wizard.next_step).to be(:test_provider_selection)
      end
    end

    context 'when answer go to another page' do
      let(:step_params) do
        { test_do_you_know_which_course: { answer: 'no' } }
      end

      it 'assigns attributes to the current step' do
        expect(wizard.next_step).to be(:test_go_to_find)
      end
    end
  end

  describe '#valid_step?' do
    let(:current_step) { :test_do_you_know_which_course }

    context 'when valid step' do
      let(:step_params) { { current_step => { answer: 'yes' } } }

      it 'returns true' do
        expect(wizard).to be_valid_step
      end

      it 'no error messages' do
        expect(wizard.current_step.errors).to be_blank
      end
    end

    context 'when invalid step' do
      let(:step_params) { {} }

      it 'returns false' do
        expect(wizard).to be_invalid_step
      end

      it 'adds error messages' do
        wizard.valid_step?
        expect(wizard.current_step.errors[:answer]).to eq(["can't be blank"])
      end
    end
  end

  describe '#permitted_params' do
    let(:current_step) { :test_do_you_know_which_course }

    it 'returns permitted params for current step' do
      expect(wizard.permitted_params).to eq([:answer])
    end
  end

  describe '#previous_step_path' do
    let(:current_step) { :test_do_you_know_which_course }

    context 'when first page' do
      let(:current_step) { :test_do_you_know_which_course }

      it 'returns the fallback' do
        expect(wizard.previous_step_path(fallback: '/fallback')).to eq('/fallback')
      end
    end

    context 'when any other page' do
      let(:current_step) { :test_provider_selection }

      before do
        # The named route is dynamic by form so we don't have the named route
        # for this spec.
        #
        without_partial_double_verification do
          allow(url_helpers).to receive(:test_wizard_test_do_you_know_which_course_path)
            .and_return('/do-you-know-which-course')
        end
      end

      it 'returns the previous step' do
        expect(wizard.previous_step_path).to eq('/do-you-know-which-course')
      end
    end

    context 'when there is default path arguments for all the steps' do
      subject(:wizard) do
        TestWizard::WizardWithDefaultScope.new(
          current_step:,
          step_params: params,
          provider_code: '1TZ',
          recruitment_cycle_year: 2025,
          code: '2T3F',
        )
      end
      let(:current_step) { :some_second_step }

      before do
        without_partial_double_verification do
          expect(url_helpers).to receive(:some_prefix_test_wizard_some_first_path)
            .with({ provider_code: '1TZ', recruitment_cycle_year: 2025, code: '2T3F' })
            .and_return('/organisations/1TZ/2025/courses/2T3F/name-selection')
        end
      end

      it 'returns the named routes for the previous step' do
        expect(wizard.previous_step_path).to eq('/organisations/1TZ/2025/courses/2T3F/name-selection')
      end
    end
  end

  describe '#next_step_path' do
    let(:current_step) { :test_do_you_know_which_course }

    context 'when next page does not exist' do
      let(:current_step) { :test_go_to_find }

      it 'raises missing step error' do
        expect {
          wizard.next_step_path
        }.to raise_error(DfE::Wizard::MissingStepError, 'Next step for TestGoToFind missing.')
      end
    end

    context 'when exiting the wizard' do
      let(:current_step) { :test_find_selection }
      let(:step_params) do
        { test_find_selection: { answer: 'no' } }
      end

      it 'assigns attributes to the current step' do
        expect(wizard.next_step_path).to eq('custom_exit_path')
      end
    end

    context 'when logger can log' do
      before do
        # The named route is dynamic by form so we don't have the named route
        # for this spec.
        #
        without_partial_double_verification do
          allow(url_helpers).to receive(:test_wizard_test_go_to_find_path).and_return('/go-to-find')
        end
      end

      it 'do log if conditions are met' do
        allow(wizard.logger).to receive(:info)
        wizard.next_step_path
        expect(wizard.logger).to have_received(:info).at_least(:once)
      end
    end

    context 'when logger can not log' do
      let(:logger) { wizard.logger }
      subject(:wizard) { TestWizard::AnotherWizard.new(current_step: :test_another_wizard_first) }

      before do
        # The named route is dynamic by form so we don't have the named route
        # for this spec.
        #
        without_partial_double_verification do
          allow(url_helpers).to receive(:test_wizard_test_another_wizard_second_path).and_return('/second-path')
        end
      end

      it 'do not log' do
        allow(logger).to receive(:info)
        allow(wizard).to receive(:log_condition?).and_return(false)
        wizard.next_step_path
        expect(logger).not_to have_received(:info)
      end
    end

    context 'when going to one branch' do
      let(:step_params) { { test_do_you_know_which_course: { answer: 'yes' } } }

      before do
        # The named route is dynamic by form so we don't have the named route
        # for this spec.
        #
        without_partial_double_verification do
          allow(url_helpers).to receive(:test_wizard_test_provider_selection_path).and_return('/provider-selection')
        end
      end

      it 'returns the named routes for the next step' do
        expect(wizard.next_step_path).to eq('/provider-selection')
      end
    end

    context 'when going to another branch' do
      let(:step_params) { { test_do_you_know_which_course: { answer: 'no' } } }

      before do
        # The named route is dynamic by form so we don't have the named route
        # for this spec.
        #
        without_partial_double_verification do
          allow(url_helpers).to receive(:test_wizard_test_go_to_find_path).and_return('/go-to-find')
        end
      end

      it 'returns the named routes for the next step' do
        expect(wizard.next_step_path).to eq('/go-to-find')
      end
    end

    context 'when needs for more arguments' do
      let(:current_step) { :test_provider_selection }
      let(:step_params) { { test_provider_selection: { provider_id: 10 } } }

      before do
        # The named route is dynamic by form so we don't have the named route
        # for this spec.
        #
        without_partial_double_verification do
          allow(url_helpers).to receive(:test_wizard_test_course_name_selection_path)
            .with({ provider_id: 10 })
            .and_return('/provider/10/courses')
        end
      end

      it 'returns the named routes for the next step' do
        expect(wizard.next_step_path).to eq('/provider/10/courses')
      end
    end

    context 'when there is default path arguments for all the steps' do
      subject(:wizard) do
        TestWizard::WizardWithDefaultScope.new(
          current_step:,
          step_params: params,
          provider_code: '1TZ',
          recruitment_cycle_year: 2025,
          code: '2T3F',
        )
      end
      let(:current_step) { :some_first_step }

      before do
        without_partial_double_verification do
          expect(url_helpers).to receive(:some_prefix_test_wizard_some_second_path)
            .with({ provider_code: '1TZ', recruitment_cycle_year: 2025, code: '2T3F' })
            .and_return('/organisations/1TZ/2025/courses/2T3F/name-selection')

          expect(url_helpers).not_to receive(:test_wizard_some_second_path)
        end
      end

      it 'returns the named routes for the next step' do
        expect(wizard.next_step_path).to eq('/organisations/1TZ/2025/courses/2T3F/name-selection')
      end
    end
  end

  describe '#save' do
    context 'when store service exists' do
      it 'calls save on wizard' do
        expect(wizard.save).to be(:save_from_store_service)
      end

      it 'pass the wizard as attribute' do
        expect(wizard.store).to be_instance_of(TestWizard::MyAwesomeStoreService)
        expect(wizard.store.wizard).to be(wizard)
      end
    end

    context 'when store service does not exist' do
      subject(:wizard) { TestWizard::AnotherWizard.new(current_step: :test_another_wizard_first) }

      it 'returns false' do
        expect(wizard.save).to be_falsey
      end
    end
  end
end
