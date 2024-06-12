module TestWizard
  class TestDoYouKnowWhichCourse < DfE::Wizard::Step
    attr_accessor :answer

    validates :answer, presence: true

    def self.permitted_params
      [:answer]
    end

    def previous_step
      :first_step
    end

    def next_step
      if answer == 'yes'
        :test_provider_selection
      else
        :test_go_to_find
      end
    end
  end

  class TestProviderSelection < DfE::Wizard::Step
    attr_accessor :provider_id

    def self.permitted_params
      %i[provider_id]
    end

    def previous_step
      :test_do_you_know_which_course
    end

    def next_step
      :test_course_name_selection
    end

    def next_step_path_arguments
      { provider_id: }
    end
  end

  class TestGoToFindStep < DfE::Wizard::Step
    def next_step; end
  end

  class TestCourseNameSelection < DfE::Wizard::Step
  end

  class TestCourseStudyModeSelection < DfE::Wizard::Step
  end

  class TestCourseSiteSelection < DfE::Wizard::Step
  end

  class TestFindSelection < DfE::Wizard::Step
    attr_accessor :answer

    def self.permitted_params
      %i[answer]
    end

    def next_step
      :exit if answer == 'no'
    end

    def exit_path
      'custom_exit_path'
    end
  end

  class TestReview < DfE::Wizard::Step
  end

  class MyAwesomeStoreService
    attr_reader :wizard

    def initialize(wizard)
      @wizard = wizard
    end

    def save
      :save_from_store_service
    end
  end

  class MyAwesomeCourseSelectionWizard < DfE::Wizard::Base
    steps do
      [
        {
          test_do_you_know_which_course: TestDoYouKnowWhichCourse,
          test_go_to_find: TestGoToFindStep,
          test_provider_selection: TestProviderSelection,
          test_course_name_selection: TestCourseNameSelection,
          test_course_study_mode_selection: TestCourseStudyModeSelection,
          test_course_site_selection: TestCourseSiteSelection,
          test_find_selection: TestFindSelection,
          test_review: TestReview,
        },
      ]
    end

    store MyAwesomeStoreService

    def logger
      if log_condition?
        @logger ||= ActiveSupport::Logger.new(STDOUT)
      end
    end

    def log_condition?
      true
    end
  end

  class TestAnotherWizardFirstStep < DfE::Wizard::Step
    def next_step
      :test_another_wizard_second
    end
  end

  class TestAnotherWizardSecondStep < DfE::Wizard::Step
  end

  class AnotherWizard < DfE::Wizard::Base
    steps do
      [
        {
          test_another_wizard_first: TestAnotherWizardFirstStep,
          test_another_wizard_second: TestAnotherWizardSecondStep,
        },
      ]
    end

    def logger
      if log_condition?
        @logger ||= ActiveSupport::Logger.new(STDOUT)
      end
    end

    def log_condition?
      true
    end
  end
end
