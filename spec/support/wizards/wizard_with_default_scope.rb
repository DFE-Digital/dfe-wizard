module TestWizard
  class SomeFirstStep < DfE::Wizard::Step
    def next_step
      :some_second_step
    end
  end

  class SomeSecondStep < DfE::Wizard::Step
    def previous_step
      :some_first_step
    end
  end

  class WizardWithDefaultScope < DfE::Wizard::Base
    attr_accessor :provider_code, :recruitment_cycle_year, :code

    steps do
      [
        { some_first_step: TestWizard::SomeFirstStep },
        { some_second_step: TestWizard::SomeSecondStep },
      ]
    end

    def default_path_arguments
      { provider_code:, recruitment_cycle_year:, code: }
    end

    def default_path_prefix
      'some_prefix'
    end
  end
end
