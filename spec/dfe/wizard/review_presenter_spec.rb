RSpec.describe DfE::Wizard::ReviewPresenter do
  let(:repository) { DfE::Wizard::Repository::InMemory.new }
  let(:state_store) { StateStores::RegisterECTStore.new(repository:) }
  let(:wizard) do
    RegisterECTWizard.new(
      current_step: :check_answers,
      state_store:,
      current_step_params: {},
    )
  end

  let(:presenter_class) do
    Class.new do
      include DfE::Wizard::ReviewPresenter

      def teacher_details
        [
          row_for(:review_ect_details, :correct_full_name),
          row_for(:email_address, :email),
          row_for(:start_date, :start_date),
        ]
      end

      def programme_details
        [
          row_for(:programme_type, :training_programme),
          row_for(:lead_provider, :lead_provider_id, label: 'Lead provider'),
        ]
      end
    end
  end

  subject(:presenter) { presenter_class.new(wizard) }

  before do
    state_store.write(
      trn: '9999999',
      date_of_birth: Date.new(2000, 1, 1),
      correct_full_name: 'John Smith',
      email: 'john@example.com',
      start_date: Date.new(2024, 9, 1),
      working_pattern: 'full_time',
      school_type: 'state',
      training_programme: 'provider_led',
      appropriate_body_name: 'Some AB',
      lead_provider_id: 'teach_first',
      details_correct: 'no',
    )
  end

  describe '#initialize' do
    it 'stores the wizard' do
      expect(presenter.wizard).to eq(wizard)
    end
  end

  describe '#row_for' do
    let(:row) { presenter.row_for(:email_address, :email) }

    it 'returns a Row object' do
      expect(row).to be_a(DfE::Wizard::ReviewPresenter::Row)
    end

    it 'sets the step_id' do
      expect(row.step_id).to eq(:email_address)
    end

    it 'sets the attribute' do
      expect(row.attribute).to eq(:email)
    end

    it 'provides the step instance' do
      expect(row.step).to be_a(Steps::RegisterECT::EmailAddressStep)
    end

    it 'provides the raw value' do
      expect(row.value).to eq('john@example.com')
    end

    it 'provides the formatted value' do
      expect(row.formatted_value).to eq('john@example.com')
    end

    it 'generates change_path with return_to_review' do
      expect(row.change_path).to include('return_to_review=email_address')
    end

    context 'with custom label' do
      let(:row) { presenter.row_for(:email_address, :email, label: 'Teacher email') }

      it 'uses the custom label' do
        expect(row.label).to eq('Teacher email')
      end
    end

    context 'with change_step override' do
      let(:row) { presenter.row_for(:email_address, :email, change_step: :start_date) }

      it 'generates change_path for the overridden step' do
        expect(row.change_path).to include('return_to_review=start_date')
      end
    end

    context 'when step does not exist' do
      it 'raises an error when step is not found' do
        expect { presenter.row_for(:nonexistent_step, :some_attr) }
          .to raise_error(NoMethodError)
      end
    end
  end

  describe '#format_value' do
    it 'returns the value unchanged by default' do
      expect(presenter.format_value(:email, 'john@example.com')).to eq('john@example.com')
    end

    context 'when overridden in presenter' do
      let(:presenter_class) do
        Class.new do
          include DfE::Wizard::ReviewPresenter

          def format_value(attribute, value)
            case attribute
            when :start_date then "Formatted: #{value}"
            else value
            end
          end
        end
      end

      it 'uses the custom formatting' do
        row = presenter.row_for(:start_date, :start_date)
        expect(row.formatted_value).to eq("Formatted: #{Date.new(2024, 9, 1)}")
      end

      it 'passes through unmatched attributes' do
        row = presenter.row_for(:email_address, :email)
        expect(row.formatted_value).to eq('john@example.com')
      end
    end
  end

  describe '#rows_for' do
    it 'returns multiple rows for a step' do
      rows = presenter.rows_for(:review_ect_details, %i[correct_full_name details_correct])
      expect(rows.length).to eq(2)
      expect(rows.map(&:attribute)).to eq(%i[correct_full_name details_correct])
    end

    it 'accepts hash options for attributes' do
      rows = presenter.rows_for(:review_ect_details, [
        :correct_full_name,
        { attribute: :details_correct, label: 'Are details correct?' },
      ])

      expect(rows[0].label).to eq('Name') # From I18n
      expect(rows[1].label).to eq('Are details correct?')
    end
  end

  describe '#change_path_for' do
    it 'generates path with return_to_review parameter' do
      path = presenter.change_path_for(:email_address)
      expect(path).to include('return_to_review=email_address')
    end
  end

  describe '#completed_steps' do
    it 'delegates to wizard.valid_steps' do
      expect(presenter.completed_steps).to eq(wizard.valid_steps)
    end
  end

  describe '#flow_steps' do
    it 'delegates to wizard.flow_steps' do
      expect(presenter.flow_steps).to eq(wizard.flow_steps)
    end
  end

  describe '#state_store' do
    it 'delegates to wizard.state_store' do
      expect(presenter.state_store).to eq(wizard.state_store)
    end
  end

  describe DfE::Wizard::ReviewPresenter::Row do
    let(:step) { wizard.step(:email_address) }
    let(:row) do
      described_class.new(
        step_id: :email_address,
        attribute: :email,
        step: step,
        change_path: '/email_address?return_to_review=email_address',
        formatted_value: 'john@example.com',
      )
    end

    describe '#value' do
      it 'returns the attribute value from the step' do
        expect(row.value).to eq('john@example.com')
      end
    end

    describe '#label' do
      it 'uses human_attribute_name from step class' do
        expect(row.label).to eq('Email address') # From I18n
      end

      context 'with custom_label' do
        let(:row) do
          described_class.new(
            step_id: :email_address,
            attribute: :email,
            step: step,
            change_path: '/email_address',
            formatted_value: 'john@example.com',
            custom_label: 'Teacher email',
          )
        end

        it 'returns the custom label' do
          expect(row.label).to eq('Teacher email')
        end
      end

      context 'without step' do
        let(:row) do
          described_class.new(
            step_id: :email_address,
            attribute: :some_attr,
            step: nil,
            change_path: '/email_address',
            formatted_value: nil,
          )
        end

        it 'humanizes the attribute name' do
          expect(row.label).to eq('Some attr')
        end
      end
    end

    describe '#value?' do
      it 'returns true when value is present' do
        expect(row.value?).to be true
      end

      context 'when value is blank' do
        before { state_store.write(email: '') }

        it 'returns false' do
          expect(row.value?).to be false
        end
      end
    end

    describe '#to_h' do
      it 'returns a hash representation' do
        result = row.to_h

        expect(result).to eq(
          step_id: :email_address,
          attribute: :email,
          label: 'Email address', # From I18n
          value: 'john@example.com',
          formatted_value: 'john@example.com',
          change_path: '/email_address?return_to_review=email_address',
        )
      end
    end
  end

  describe 'grouping rows in presenter methods' do
    it 'allows grouping rows by section' do
      expect(presenter.teacher_details.map(&:attribute)).to eq(%i[correct_full_name email start_date])
      expect(presenter.programme_details.map(&:attribute)).to eq(%i[training_programme lead_provider_id])
    end

    it 'uses custom labels in grouped rows' do
      labels = presenter.programme_details.map(&:label)
      expect(labels).to include('Lead provider')
    end
  end
end
