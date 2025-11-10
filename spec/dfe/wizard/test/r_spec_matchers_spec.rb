RSpec.describe DfE::Wizard::Test::RSpecMatchers do
  let(:wizard) do
    PersonalInformationWizard.new(
      current_step: current_step,
      state_store: DfE::Wizard::StateStore::Session.new(session: session, key: 'test_wizard'),
      step_params: ActionController::Parameters.new(step_params),
    )
  end

  let(:session) { {} }
  let(:step_params) { {} }
  let(:current_step) { :name_and_date_of_birth }

  describe '#be_at_step' do
    context 'when wizard is at expected step' do
      let(:current_step) { :nationality }

      it 'passes' do
        expect(wizard).to be_at_step(:nationality)
      end
    end

    context 'when wizard is not at expected step' do
      let(:current_step) { :name_and_date_of_birth }

      it 'fails with detailed message' do
        expect {
          expect(wizard).to be_at_step(:nationality)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Expected wizard to be at step/)
      end

      it 'includes current step in failure message' do
        expect {
          expect(wizard).to be_at_step(:nationality)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Current step: :name_and_date_of_birth/)
      end

      it 'includes path traversal in failure message' do
        expect {
          expect(wizard).to be_at_step(:nationality)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Path traversal:/)
      end
    end
  end

  describe '#have_visited' do
    context 'when wizard has visited all expected steps' do
      let(:current_step) { :nationality }
      let(:session) do
        {
          'test_wizard' => {
            'steps' => {
              'name_and_date_of_birth' => { 'first_name' => 'John', 'last_name' => 'Doe',
                                            'date_of_birth' => '1990-01-01' },
            },
          },
        }
      end

      it 'passes' do
        expect(wizard).to have_visited(:name_and_date_of_birth, :nationality)
      end
    end

    context 'when wizard has not visited some steps' do
      let(:current_step) { :name_and_date_of_birth }

      it 'fails with detailed message' do
        expect {
          expect(wizard).to have_visited(:name_and_date_of_birth, :nationality, :review)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Missing steps:/)
      end

      it 'shows which steps were not visited' do
        expect {
          expect(wizard).to have_visited(:name_and_date_of_birth, :review)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /\[:review\]/)
      end
    end
  end

  describe '#be_able_to_reach' do
    context 'when target step is reachable' do
      let(:current_step) { :name_and_date_of_birth }

      it 'passes' do
        expect(wizard).to be_able_to_reach(:nationality)
      end
    end

    context 'when target step is not reachable' do
      let(:current_step) { :name_and_date_of_birth }

      it 'fails with diagnostic information' do
        expect {
          expect(wizard).to be_able_to_reach(:nonexistent_step)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Expected wizard to be able to reach/)
      end

      it 'explains why step is unreachable' do
        expect {
          expect(wizard).to be_able_to_reach(:nonexistent_step)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError,
                         /Target step :nonexistent_step does not exist in graph/)
      end
    end
  end

  describe '#have_valid_path_to' do
    context 'when all steps in path are valid' do
      let(:current_step) { :name_and_date_of_birth }
      let(:session) do
        {
          'test_wizard' => {
            'steps' => {
              'name_and_date_of_birth' => {
                'first_name' => 'John',
                'last_name' => 'Doe',
                'date_of_birth' => '1990-01-01',
              },
            },
          },
        }
      end

      it 'passes' do
        expect(wizard).to have_valid_path_to(:nationality)
      end
    end

    context 'when a step in path is invalid' do
      let(:current_step) { :nationality }
      let(:session) do
        {
          'test_wizard' => {
            'steps' => {
              'name_and_date_of_birth' => {
                'first_name' => '',  # Invalid!
                'last_name' => 'Doe',
                'date_of_birth' => '1990-01-01',
              },
            },
          },
        }
      end

      it 'fails with validation errors' do
        expect {
          expect(wizard).to have_valid_path_to(:nationality)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /First invalid step:/)
      end

      it 'shows which step is invalid' do
        expect {
          expect(wizard).to have_valid_path_to(:nationality)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /:name_and_date_of_birth/)
      end

      it 'shows validation error messages' do
        expect {
          expect(wizard).to have_valid_path_to(:nationality)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Validation errors/)
      end
    end
  end

  describe '#be_reachable' do
    context 'when step is reachable' do
      let(:current_step) { :name_and_date_of_birth }

      it 'passes' do
        expect(:nationality).to be_reachable.in(wizard)
      end
    end

    context 'when step does not exist' do
      let(:current_step) { :name_and_date_of_birth }

      it 'fails' do
        expect {
          expect(:nonexistent).to be_reachable.in(wizard)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Expected step/)
      end

      it 'shows step does not exist in graph' do
        expect {
          expect(:nonexistent).to be_reachable.in(wizard)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Step exists in graph: false/)
      end
    end
  end

  describe '#be_accessible' do
    context 'when step is accessible with valid previous steps' do
      let(:current_step) { :nationality }
      let(:session) do
        {
          'test_wizard' => {
            'steps' => {
              'name_and_date_of_birth' => {
                'first_name' => 'John',
                'last_name' => 'Doe',
                'date_of_birth' => '1990-01-01',
              },
            },
          },
        }
      end

      it 'passes' do
        expect(:nationality).to be_accessible.in(wizard)
      end
    end

    context 'when step is not accessible due to invalid previous step' do
      let(:current_step) { :review }
      let(:session) do
        {
          'test_wizard' => {
            'steps' => {
              'name_and_date_of_birth' => {
                'first_name' => '',  # Invalid
              },
            },
          },
        }
      end

      it 'fails' do
        expect {
          expect(:review).to be_accessible.in(wizard)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Expected step/)
      end

      it 'shows invalid previous steps' do
        expect {
          expect(:review).to be_accessible.in(wizard)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Invalid previous steps/)
      end
    end
  end

  describe 'integration with real wizard flow' do
    let(:session) do
      {
        'test_wizard' => {
          'steps' => {
            'name_and_date_of_birth' => {
              'first_name' => 'Jane',
              'last_name' => 'Smith',
              'date_of_birth' => '1985-05-15',
            },
            'nationality' => {
              'nationalities' => ['british'],
            },
          },
        },
      }
    end

    let(:current_step) { :review }

    it 'validates complete wizard flow' do
      expect(wizard).to be_at_step(:review)
      expect(wizard).to have_visited(:name_and_date_of_birth, :nationality)
      expect(wizard).to have_valid_path_to(:review)
      expect(:review).to be_reachable.in(wizard)
      expect(:review).to be_accessible.in(wizard)
    end
  end
end
