RSpec.describe DfE::Wizard::Step do
  let(:wizard) do
    PersonalInformationWizard.new(
      current_step: :name_and_date_of_birth,
      state_store: StateStores::PersonalInformation.new(repository: DfE::Wizard::Repository::InMemory.new),
    )
  end

  let(:email_step) { Steps::NameAndDateOfBirth }
  let(:nationality_step) { Steps::Nationality }

  describe '.new' do
    it 'assigns wizard and step_id' do
      step = email_step.new(
        first_name: 'Ziggy',
        last_name: 'Stardust',
        date_of_birth: Date.new(1999, 1, 2),
        wizard:,
        step_id: :name_and_date_of_birth,
      )
      expect(step.wizard).to eq(wizard)
      expect(step.step_id).to eq(:name_and_date_of_birth)
    end

    it 'assigns real attributes' do
      step = email_step.new(
        first_name: 'Ziggy',
        last_name: 'Stardust',
        date_of_birth: Date.new(1999, 1, 2),
      )
      expect(step.first_name).to eq('Ziggy')
      expect(step.last_name).to eq('Stardust')
      expect(step.date_of_birth).to eq(Date.new(1999, 1, 2))
    end

    it 'serializes only model data and not wizard context' do
      step = email_step.new(
        first_name: 'Ziggy',
        last_name: 'Stardust',
        date_of_birth: Date.new(1999, 1, 2),
        wizard: wizard,
        step_id: :name_and_date_of_birth,
      )
      expect(step.serializable_data).not_to have_key('wizard')
      expect(step.serializable_data).not_to have_key('step_id')
      expect(step.serializable_data).to include('first_name', 'last_name', 'date_of_birth')
    end

    it 'can be initialized with no params' do
      step = email_step.new
      expect(step.first_name).to be_nil
      expect(step.last_name).to be_nil
    end
  end

  describe '.model_name' do
    it 'returns namespaced model name' do
      expect(email_step.model_name.name).to eq('Steps::NameAndDateOfBirth')
    end

    it 'returns namespaced param_key' do
      expect(email_step.model_name.param_key).to eq('steps_name_and_date_of_birth')
    end
  end

  describe '.permitted_params' do
    it 'returns symbol array for NameAndDateOfBirth step' do
      expect(email_step.permitted_params).to match_array(%w[date_of_birth first_name last_name])
    end

    it 'returns symbol array for Nationality step' do
      expect(nationality_step.permitted_params).to eq([{ nationalities: [] }, :other_nationality])
    end
  end

  describe '#serializable_data' do
    it 'returns model attributes as a hash' do
      step = email_step.new(first_name: 'Amy')
      expect(step.serializable_data).to include('first_name' => 'Amy')
    end
  end

  describe 'validation' do
    it 'validates presence of first_name' do
      step = email_step.new(last_name: 'Doe', date_of_birth: Date.today)
      expect(step).not_to be_valid
      expect(step.errors[:first_name]).to be_present
    end

    it 'validates presence of last_name' do
      step = email_step.new(first_name: 'Joe', date_of_birth: Date.today)
      expect(step).not_to be_valid
      expect(step.errors[:last_name]).to be_present
    end

    it 'is valid with all required fields' do
      step = email_step.new(first_name: 'Jane', last_name: 'Doe', date_of_birth: Date.today)
      expect(step).to be_valid
    end
  end

  describe 'form helper compatibility' do
    it 'has param_key for #form_with' do
      expect(email_step.model_name.param_key).to eq('steps_name_and_date_of_birth')
    end

    it 'exposes form errors' do
      step = email_step.new
      step.valid?
      expect(step.errors.full_messages).to be_any
    end
  end

  describe 'typecasting' do
    it 'typecasts date_of_birth from string' do
      step = email_step.new(first_name: 'Joe', last_name: 'Smith', date_of_birth: '2001-01-10')
      expect(step.date_of_birth).to be_a(Date)
      expect(step.date_of_birth).to eq(Date.new(2001, 1, 10))
    end
  end

  describe 'wizard context integration' do
    it 'maintains wizard context after validation' do
      step = email_step.new(first_name: 'A', last_name: 'B', date_of_birth: Date.today, wizard: wizard,
                            step_id: :name_and_date_of_birth)
      step.valid?
      expect(step.wizard).to eq(wizard)
      expect(step.step_id).to eq(:name_and_date_of_birth)
    end

    it 'allows setting wizard context after initialization' do
      step = email_step.new(first_name: 'Ziggy')
      step.wizard = wizard
      step.step_id = :xyz
      expect(step.wizard).to eq(wizard)
      expect(step.step_id).to eq(:xyz)
    end
  end
end
