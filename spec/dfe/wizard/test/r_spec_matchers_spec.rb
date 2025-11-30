RSpec.describe DfE::Wizard::Test::RSpecMatchers do
  let(:repository) { DfE::Wizard::Repository::InMemory.new }
  let(:state_store) { StateStores::PersonalInformation.new(repository:) }
  let(:current_step) { :name_and_date_of_birth }
  let(:steps_data) { {} }
  let(:state_store_class) do
    Class.new do
      include DfE::Wizard::StateStore
    end
  end

  let(:wizard) do
    PersonalInformationWizard.new(
      current_step:,
      state_store:,
    )
  end

  before do
    repository.write(steps_data) if steps_data.any?
  end

  describe '#be_at_step' do
    let(:current_step) { :nationality }

    it 'passes if at the expected step' do
      expect(wizard).to be_at_step(:nationality)
    end

    it 'fails with a clear message if not' do
      expect {
        expect(wizard).to be_at_step(:review)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
        expect(error.message).to include('Expected current step: :review')
      end
    end
  end

  describe 'list-based path matchers: flow, saved, valid' do
    let(:steps_data) do
      {
        first_name: 'John',
        last_name: 'Doe',
        date_of_birth: '1990-01-01',
        nationalities: 'british',
      }
    end
    let(:current_step) { :review }

    it 'matches flow_path exactly' do
      expect(wizard).to have_flow_path(%i[name_and_date_of_birth nationality review])
    end

    it 'matches saved_path exactly' do
      expect(wizard).to have_saved_path(%i[name_and_date_of_birth nationality])
    end

    it 'matches valid_path exactly, even if all steps are valid' do
      expect(wizard).to have_valid_path(%i[name_and_date_of_birth nationality review])
    end

    it 'fails if path does not match' do
      expect {
        expect(wizard).to have_flow_path(%i[name_and_date_of_birth review])
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
        expect(error.message).to include('Expected flow_path')
      end

      expect {
        expect(wizard).to have_saved_path(%i[name_and_date_of_birth review])
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
        expect(error.message).to include('Expected saved_path')
      end

      expect {
        expect(wizard).to have_valid_path(%i[name_and_date_of_birth review])
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
        expect(error.message).to include('Expected valid_path')
      end
    end
  end

  describe 'step object matchers for flow/saved/valid steps' do
    let(:steps_data) do
      {
        first_name: 'John',
        last_name: 'Doe',
        date_of_birth: '1990-01-01',
        nationalities: 'british',
      }
    end
    let(:current_step) { :review }

    let(:expected_steps) do
      [
        Steps::NameAndDateOfBirth.new(
          steps_data.slice(:first_name, :last_name, :date_of_birth).merge(
            step_id: :name_and_date_of_birth,
          ),
        ),
        Steps::Nationality.new(
          steps_data.slice(:nationalities).merge(
            step_id: :nationality,
          ),
        ),
        Steps::Review.new(step_id: :review),
      ]
    end

    it 'matches flow_steps by class and object equality' do
      expect(wizard).to have_flow_steps(expected_steps)
    end

    it 'matches saved_steps by class and object equality' do
      expect(wizard).to have_saved_steps(expected_steps[0..-2])
    end

    it 'matches valid_steps by class and object equality' do
      expect(wizard).to have_valid_steps(expected_steps)
    end

    it 'fails if expected and actual steps differ' do
      actual = wizard.flow_steps.dup
      bad_steps = actual.dup
      bad_steps.pop
      expect {
        expect(wizard).to have_flow_steps(bad_steps)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
        expect(error.message).to include('Expected flow_steps')
      end
    end
  end

  describe '#be_valid_to' do
    let(:steps_data) do
      {
        first_name: '',
        last_name: 'Doe',
        date_of_birth: '1990-01-01',
        nationalities: 'british',
      }
    end
    let(:current_step) { :nationality }

    it 'passes if all steps to the target are valid' do
      repository.write({
                         first_name: 'Jane',
                         last_name: 'Smith',
                         date_of_birth: '1950-01-01',
                       })
      expect(wizard).to be_valid_to(:nationality)
    end

    it 'fails with full error diagnostic if any step invalid' do
      expect {
        expect(wizard).to be_valid_to(:nationality)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
        expect(error.message).to include('step(s) invalid before reaching :nationality')
      end
    end
  end

  describe '#be_valid (single step)' do
    let(:steps_data) do
      {
        first_name: '',
        last_name: 'Doe',
        date_of_birth: '1990-01-01',
      }
    end
    let(:current_step) { :nationality }

    it 'fails on invalid' do
      expect {
        expect(:name_and_date_of_birth).to be_valid_step.in(wizard)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
        expect(error.message).to include('Step invalid: :name_and_date_of_birth')
      end
    end

    it 'passes on valid' do
      repository.write({
                         first_name: 'Valid',
                         last_name: 'Doe',
                         date_of_birth: '1990-01-01',
                       })
      expect(:name_and_date_of_birth).to be_valid_step.in(wizard)
    end
  end

  describe '#branch_from' do
    let(:steps_data) do
      {
        first_name: 'Alice',
        last_name: 'Smith',
        date_of_birth: '1980-02-22',
        nationalities: nationalities,
      }
    end
    let(:current_step) { :nationality }

    context 'for UK/Irish' do
      let(:nationalities) { 'british' }

      it 'branches to review from nationality' do
        expect(wizard).to branch_from(:nationality).to(:review)
      end
    end

    context 'for non-UK with right to work' do
      let(:nationalities) { 'french' }

      it 'branches to right_to_work_or_study from nationality' do
        expect(wizard).to branch_from(:nationality).to(:right_to_work_or_study)
      end
    end

    context 'when actual next step is different' do
      let(:nationalities) { 'french' }

      it 'fails with correct details' do
        expect {
          expect(wizard).to branch_from(:nationality).to(:review)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include('Expected to branch from :nationality to: :review')
        end
      end
    end
  end

  describe '#resolve_step' do
    let(:repository) { DfE::Wizard::Repository::InMemory.new }
    let(:state_store) { StateStores::PersonalInformation.new(repository:) }
    let(:url_helpers) { Rails.application.routes.url_helpers }

    subject(:wizard) do
      PersonalInformationWizard.new(
        current_step: :nationality,
        state_store:,
      )
    end

    describe 'resolves step to correct path' do
      it 'matches when step resolves to expected path' do
        expect(wizard).to resolve_step(:nationality)
          .to(url_helpers.personal_information_nationality_path)
      end

      it 'fails when step does not resolve to expected path' do
        expect {
          expect(wizard).to resolve_step(:nationality)
            .to('/wrong-path')
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include('Expected step :nationality to resolve to')
        end
      end

      it 'requires .to() chain' do
        expect {
          expect(wizard).to resolve_step(:nationality)
        }.to raise_error(ArgumentError) do |error|
          expect(error.message).to include('Must specify .to(path)')
        end
      end

      it 'resolves multiple steps correctly' do
        expect(wizard).to resolve_step(:name_and_date_of_birth)
          .to(url_helpers.personal_information_name_and_date_of_birth_path)
        expect(wizard).to resolve_step(:nationality)
          .to(url_helpers.personal_information_nationality_path)
        expect(wizard).to resolve_step(:review)
          .to(url_helpers.personal_information_review_path)
      end
    end

    describe 'with different route strategies' do
      context 'using NamedRoutes strategy' do
        it 'resolves steps using named route convention' do
          expect(wizard).to resolve_step(:nationality)
            .to(url_helpers.personal_information_nationality_path)
        end
      end

      context 'with string paths' do
        it 'matches string path directly' do
          actual_path = wizard.resolve_step_path(:nationality)
          expect(wizard).to resolve_step(:nationality).to(actual_path)
        end
      end
    end

    describe 'failure messages' do
      it 'includes step id in failure message' do
        expect {
          expect(wizard).to resolve_step(:nationality).to('/wrong')
        }.to raise_error(/step :nationality/)
      end

      it 'includes expected and actual paths in failure message' do
        expected = '/expected-path'
        actual = wizard.resolve_step_path(:nationality)

        expect {
          expect(wizard).to resolve_step(:nationality).to(expected)
        }.to raise_error(
          /Expected step :nationality to resolve to: "#{expected}"\nGot: "#{actual}"/,
        )
      end

      it 'includes route strategy class name in failure message' do
        expect {
          expect(wizard).to resolve_step(:nationality).to('/wrong')
        }.to raise_error(/Route strategy:/)
      end
    end

    describe 'consistency across multiple calls' do
      it 'resolves the same step to the same path consistently' do
        path_one = wizard.resolve_step_path(:nationality)
        path_two = wizard.resolve_step_path(:nationality)

        expect(wizard).to resolve_step(:nationality).to(path_one)
        expect(wizard).to resolve_step(:nationality).to(path_two)
      end
    end
  end

  describe 'attribute presence and value in state_store' do
    it 'matches attributes and values' do
      state_store.write(first_name: 'Graham', last_name: 'Lee')
      expect(state_store).to have_step_attribute(:first_name)
      expect(state_store).to have_step_attribute(:first_name).with_value('Graham')

      expect {
        expect(state_store).to have_step_attribute(:undefined_method).with_value('Graham')
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
        expect(error.message).to include('Expected :undefined_method to be "Graham", but got: nil')
      end
    end
  end

  describe '#have_root_step' do
    let(:simple_state_store) { state_store_class.new }

    let(:wizard_class) do
      Class.new do
        attr_accessor :current_step_name, :state_store

        def initialize(state_store:)
          @current_step_name = :step_a
          @state_store = state_store
        end

        def step(step_name)
          OpenStruct.new(id: step_name)
        end

        def steps_processor
          @steps_processor ||= DfE::Wizard::StepsProcessor::Graph.draw(self) do |g|
            g.add_node :step_a, Class.new
            g.add_node :step_b, Class.new
            g.root :step_a
          end
        end
      end
    end

    let(:wizard) { wizard_class.new(state_store: simple_state_store) }

    describe 'positive assertions' do
      it 'passes when root node matches' do
        expect(wizard).to have_root_step(:step_a)
      end

      it 'fails when root node does not match' do
        expect {
          expect(wizard).to have_root_step(:step_b)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include(':step_b')
          expect(error.message).to include(':step_a')
        end
      end
    end

    describe 'negative assertions' do
      it 'passes when root node does not match' do
        expect(wizard).not_to have_root_step(:step_b)
      end

      it 'fails when root node matches' do
        expect {
          expect(wizard).not_to have_root_step(:step_a)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    describe 'error messages' do
      it 'provides helpful failure message' do
        expect {
          expect(wizard).to have_root_step(:wrong_step)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include('expected wizard to have root node')
          expect(error.message).to include(':wrong_step')
          expect(error.message).to include(':step_a')
        end
      end

      it 'provides helpful negation failure message' do
        expect {
          expect(wizard).not_to have_root_step(:step_a)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include('expected wizard not to have root node')
          expect(error.message).to include(':step_a')
        end
      end
    end

    describe 'with conditional_root' do
      let(:conditional_root_state_store) { state_store_class.new }

      let(:wizard_with_conditional) do
        Class.new do
          attr_accessor :current_step_name, :state_store

          def initialize(state_store:)
            @current_step_name = :entry
            @state_store = state_store
          end

          def step(step_name)
            OpenStruct.new(id: step_name)
          end

          def steps_processor
            @steps_processor ||= DfE::Wizard::StepsProcessor::Graph.draw(self) do |g|
              g.add_node :step_a, Class.new
              g.add_node :step_b, Class.new
              g.conditional_root { :step_b }
            end
          end
        end.new(state_store: conditional_root_state_store)
      end

      it 'works with conditional_root that returns fixed step' do
        expect(wizard_with_conditional).to have_root_step(:step_b)
      end
    end

    describe 'description' do
      it 'provides a clear description' do
        matcher = have_root_step(:step_a)
        expect(matcher.description).to eq('have root node :step_a')
      end
    end
  end

  describe '#have_root_step with .when chain' do
    let(:conditional_entry_state_store) { state_store_class.new }

    let(:wizard_class) do
      Class.new do
        attr_accessor :current_step_name, :state_store

        def initialize(state_store:)
          @current_step_name = :entry
          @state_store = state_store
        end

        def step(step_name)
          OpenStruct.new(id: step_name)
        end

        def steps_processor
          @steps_processor ||= DfE::Wizard::StepsProcessor::Graph.draw(self) do |g|
            g.add_node :entry, Class.new
            g.add_node :form, Class.new
            g.add_node :review, Class.new
            g.conditional_root :determine_entry
          end
        end

        def determine_entry
          if state_store.read[:mode] == 'edit'
            :review
          else
            :form
          end
        end
      end
    end

    let(:wizard) { wizard_class.new(state_store: conditional_entry_state_store) }

    describe 'create mode' do
      it 'enters at form when mode is create' do
        expect(wizard).to have_root_step(:form).when(mode: 'create')
      end

      it 'enters at form even without explicit when' do
        wizard.state_store.write(mode: 'create')
        expect(wizard).to have_root_step(:form)
      end
    end

    describe 'edit mode' do
      it 'enters at review when mode is edit' do
        expect(wizard).to have_root_step(:review).when(mode: 'edit')
      end

      it 'returns to form when mode is not edit' do
        expect(wizard).to have_root_step(:form).when(mode: 'create')
      end
    end

    describe 'when chain behavior' do
      it 'writes state data before evaluating root' do
        expect(wizard).to have_root_step(:review).when(mode: 'edit')
        expect(wizard.state_store.read[:mode]).to eq('edit')
      end

      it 'multiple when calls all use the when data' do
        expect(wizard).to have_root_step(:review).when(mode: 'edit')
        expect(wizard).to have_root_step(:form).when(mode: 'create')
      end

      it 'fails if state data makes root mismatch' do
        expect {
          expect(wizard).to have_root_step(:form).when(mode: 'edit')
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include(':form')
          expect(error.message).to include(':review')
        end
      end
    end

    describe 'complex state scenarios' do
      it 'handles multiple state attributes' do
        expect(wizard).to have_root_step(:review)
          .when(mode: 'edit', user_type: 'admin', status: 'approved')
      end

      it 'overrides previously set state' do
        wizard.state_store.write(mode: 'view')
        expect(wizard).to have_root_step(:review).when(mode: 'edit')
      end

      it 'preserves other state when applying when data' do
        wizard.state_store.write(user_id: 123, user_type: 'admin')
        expect(wizard).to have_root_step(:review).when(mode: 'edit')

        expect(wizard.state_store.read[:user_id]).to eq(123)
        expect(wizard.state_store.read[:user_type]).to eq('admin')
      end
    end

    describe 'when chain with negation' do
      it 'fails if root matches when negated with when' do
        expect {
          expect(wizard).not_to have_root_step(:review).when(mode: 'edit')
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include('not to have root node')
        end
      end

      it 'passes if root does not match when negated with when' do
        expect(wizard).not_to have_root_step(:form).when(mode: 'edit')
      end
    end
  end
end
