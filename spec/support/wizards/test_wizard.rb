DummyNode = Struct.new(:id, :klass)

class DummyStep
  attr_reader :wizard, :name

  def initialize(args = {})
    @wizard = args[:wizard]
    @name = args[:name]
  end

  def valid?
    name.present?
  end

  def errors
    OpenStruct.new(blank?: false)
  end

  def serializable_data
    { name: }
  end
end

module TestWizard
  class EmailStep < DfE::Wizard::Step
    attr_accessor :email

    def next_step
      :verify_step
    end

    def previous_step
      :first_step
    end
  end

  class VerifyStep < DfE::Wizard::Step
    attr_accessor :code

    def next_step
      :profile_step
    end

    def previous_step
      :email_step
    end
  end

  class ProfileStep < DfE::Wizard::Step
    def next_step
      :confirm_step
    end

    def previous_step
      :verify_step
    end
  end

  class ConfirmStep < DfE::Wizard::Step
    def next_step
      :finished_step
    end

    def previous_step
      :profile_step
    end
  end

  class FinishedStep < DfE::Wizard::Step
    def previous_step
      :confirm_step
    end

    def next_step
      :exit
    end

    def exit_path
      "/wizard/complete"
    end
  end

  class LegacyStore
    attr_reader :wizard

    def initialize(wizard)
      @wizard = wizard
    end

    def save
      :saved_legacy
    end

    def update
      :updated_legacy
    end
  end

  class LegacyWizard < DfE::Wizard::Base
    steps do
      [
        { email_step: EmailStep },
        { verify_step: VerifyStep },
        { profile_step: ProfileStep },
        { confirm_step: ConfirmStep },
        { finished_step: FinishedStep }
      ]
    end

    store LegacyStore
  end
end
