RSpec.describe DfE::Wizard::Core::StateStore do
  # ============================================================================
  # WIZARD: Apply for Basic DBS Check
  # ============================================================================

  let(:wizard_class) do
    Class.new do
      include DfE::Wizard

      def steps_processor
        DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
          graph.add_node :start, DBSSteps::Start
          graph.add_node :what_service, DBSSteps::WhatService
          graph.add_node :personal_details, DBSSteps::PersonalDetails
          graph.add_node :address_history, DBSSteps::AddressHistory
          graph.add_node :previous_names_question, DBSSteps::PreviousNamesQuestion
          graph.add_node :previous_names_details, DBSSteps::PreviousNamesDetails
          graph.add_node :identity_documents, DBSSteps::IdentityDocuments
          graph.add_node :contact_preferences, DBSSteps::ContactPreferences
          graph.add_node :payment, DBSSteps::Payment
          graph.add_node :check_answers, DBSSteps::CheckAnswers

          graph.root :start

          graph.add_edge from: :start, to: :what_service
          graph.add_edge from: :what_service, to: :personal_details
          graph.add_edge from: :personal_details, to: :address_history
          graph.add_edge from: :address_history, to: :previous_names_question
          graph.add_conditional_edge(
            from: :previous_names_question,
            when: :has_previous_names?,
            then: :previous_names_details,
            else: :identity_documents,
          )
          graph.add_edge from: :previous_names_details, to: :identity_documents
          graph.add_edge from: :identity_documents, to: :contact_preferences
          graph.add_edge from: :contact_preferences, to: :payment
          graph.add_edge from: :payment, to: :check_answers
        end
      end

      def route_strategy
        DfE::Wizard::RouteStrategy::ConfigurableRoutes.new(wizard: self)
      end

      def logger
        @logger ||= DfE::Wizard::Logger.new(Rails.logger)
      end

    end
  end

  let(:state_store_class) do
    Class.new do
      include DfE::Wizard::Core::StateStore

      def has_previous_names?
        previous_names == 'yes'
      end

      def full_name
        "#{first_name} #{middle_names} #{last_name}".squeeze(' ').strip
      end

      def age
        return nil unless date_of_birth

        Date.parse(date_of_birth).then do |dob|
          ((Date.today - dob).to_i / 365.25).floor
        end
      rescue ArgumentError
        nil
      end

      def uk_resident?
        country_of_residence == 'united_kingdom'
      end

      def attribute_redefined_in_state_store
        :this_attribute_is_redefined
      end
    end
  end

  before(:all) do
    unless defined?(DBSSteps::Start)
      module DBSSteps
        class Start
          include DfE::Wizard::Step

          def self.permitted_params
            []
          end
        end

        class WhatService
          include DfE::Wizard::Step

          attribute :service_type

          validates :service_type,
                    presence: true,
                    inclusion: { in: %w[basic standard enhanced] }

          def self.permitted_params
            %w[service_type]
          end
        end

        class PersonalDetails
          include DfE::Wizard::Step

          attribute :first_name
          attribute :middle_names
          attribute :last_name
          attribute :date_of_birth
          attribute :gender
          attribute :country_of_birth

          validates :first_name, :last_name, :date_of_birth, :gender, presence: true
          validates :gender, inclusion: { in: %w[male female prefer_not_to_say] }

          def self.permitted_params
            %w[first_name middle_names last_name date_of_birth gender country_of_birth]
          end
        end

        class AddressHistory
          include DfE::Wizard::Step

          attribute :current_address_line_1
          attribute :current_address_line_2
          attribute :current_address_town
          attribute :current_address_postcode
          attribute :current_address_country
          attribute :lived_here_since

          validates :current_address_line_1,
                    :current_address_town,
                    :current_address_postcode,
                    presence: true

          def self.permitted_params
            %w[
              current_address_line_1
              current_address_line_2
              current_address_town
              current_address_postcode
              current_address_country
              lived_here_since
            ]
          end
        end

        class PreviousNamesQuestion
          include DfE::Wizard::Step

          attribute :previous_names

          validates :previous_names,
                    presence: true,
                    inclusion: { in: %w[yes no] }

          def self.permitted_params
            %w[previous_names]
          end
        end

        class PreviousNamesDetails
          include DfE::Wizard::Step

          attribute :previous_first_name
          attribute :previous_middle_names
          attribute :previous_last_name
          attribute :name_changed_date
          attribute :reason_for_change
          attribute :attribute_redefined_in_state_store

          validates :previous_first_name, :previous_last_name, presence: true

          def self.permitted_params
            %w[
              previous_first_name
              previous_middle_names
              previous_last_name
              name_changed_date
              reason_for_change
            ]
          end
        end

        class IdentityDocuments
          include DfE::Wizard::Step

          attribute :document_type
          attribute :passport_number
          attribute :driving_license_number
          attribute :national_insurance_number

          validates :document_type,
                    presence: true,
                    inclusion: { in: %w[passport driving_license both] }

          def self.permitted_params
            %w[
              document_type
              passport_number
              driving_license_number
              national_insurance_number
            ]
          end
        end

        class ContactPreferences
          include DfE::Wizard::Step

          attribute :email
          attribute :phone
          attribute :contact_method
          attribute :country_of_residence

          validates :email, :phone, :contact_method, presence: true
          validates :contact_method, inclusion: { in: %w[email phone post] }

          def self.permitted_params
            %w[email phone contact_method country_of_residence]
          end
        end

        class Payment
          include DfE::Wizard::Step

          attribute :payment_method
          attribute :card_number
          attribute :card_expiry
          attribute :card_cvv

          validates :payment_method, presence: true

          def self.permitted_params
            %w[payment_method card_number card_expiry card_cvv]
          end
        end

        class CheckAnswers
          include DfE::Wizard::Step

          def self.permitted_params
            []
          end
        end
      end
    end
  end

  let(:repository) { DfE::Wizard::Repository::InMemory.new }
  let(:state_store) { state_store_class.new(repository:) }
  let(:wizard) do
    wizard_class.new(
      current_step: :start,
      state_store:,
    )
  end

  describe '#initialize' do
    it 'accepts a repository' do
      expect(state_store.repository).to eq(repository)
    end

    it 'initializes step_definitions as empty array' do
      expect(state_store.step_definitions).to eq([])
    end

    it 'initializes attribute_names as empty array' do
      expect(state_store.attribute_names).to eq([])
    end
  end

  describe '#read, #write, #clear delegation' do
    it 'delegates read to repository' do
      expect(repository).to receive(:read).and_return({})
      state_store.read
    end

    it 'delegates write to repository' do
      flat_hash = { first_name: 'John', email: 'john@example.com' }
      expect(repository).to receive(:write).with(flat_hash)
      state_store.write(flat_hash)
    end

    it 'delegates clear to repository' do
      expect(repository).to receive(:clear)
      state_store.clear
    end

    it 'read returns flat hash from repository' do
      repository.write({ first_name: 'Sarah', email: 'sarah@example.com' })
      result = state_store.read

      expect(result).to eq({ first_name: 'Sarah', email: 'sarah@example.com' })
    end

    it 'write stores flat hash in repository' do
      state_store.write({ first_name: 'John', last_name: 'Doe' })

      expect(repository.read).to eq({ first_name: 'John', last_name: 'Doe' })
    end

    it 'clear removes all data from repository' do
      state_store.write({ first_name: 'John' })
      state_store.clear

      expect(repository.read).to eq({})
    end
  end

  describe '#step_attributes_methods?' do
    it 'returns true by default' do
      expect(state_store.step_attributes_methods?).to be true
    end

    it 'can be overridden to disable auto-generation' do
      custom_store = Class.new do
        include DfE::Wizard::Core::StateStore

        def step_attributes_methods?
          false
        end
      end

      instance = custom_store.new(repository:)
      expect(instance.step_attributes_methods?).to be false
    end
  end

  describe '#method_missing and #respond_to_missing?' do
    context 'with complete DBS check application' do
      before do
        repository.write({
                           service_type: 'basic',
                           first_name: 'Sarah',
                           middle_names: 'Elizabeth',
                           last_name: 'Johnson',
                           date_of_birth: '1985-03-15',
                           gender: 'female',
                           country_of_birth: 'United Kingdom',
                           current_address_line_1: '10 Downing Street',
                           current_address_line_2: 'Westminster',
                           current_address_town: 'London',
                           current_address_postcode: 'SW1A 2AA',
                           current_address_country: 'United Kingdom',
                           lived_here_since: '2020-01-01',
                           previous_names: 'yes',
                           previous_first_name: 'Sarah',
                           previous_last_name: 'Smith',
                           name_changed_date: '2010-06-20',
                           reason_for_change: 'marriage',
                           document_type: 'both',
                           passport_number: '123456789',
                           driving_license_number: 'JOHNS851203AB9CD',
                           national_insurance_number: 'AB123456C',
                           email: 'sarah.johnson@example.com',
                           phone: '07700900123',
                           contact_method: 'email',
                           country_of_residence: 'united_kingdom',
                           payment_method: 'card',
                           card_number: '4111111111111111',
                         })

        state_store.step_definitions = wizard.step_definitions
        state_store.attribute_names = wizard.attribute_names
      end

      it 'responds to all step attributes via method_missing' do
        expect(state_store).to respond_to(:service_type)
        expect(state_store).to respond_to(:first_name)
        expect(state_store).to respond_to(:last_name)
        expect(state_store).to respond_to(:date_of_birth)
        expect(state_store).to respond_to(:email)
        expect(state_store).to respond_to(:passport_number)
      end

      it 'returns correct values via method_missing' do
        expect(state_store.service_type).to eq('basic')
        expect(state_store.first_name).to eq('Sarah')
        expect(state_store.last_name).to eq('Johnson')
        expect(state_store.email).to eq('sarah.johnson@example.com')
      end

      it 'method_missing reads from current repository data' do
        repository.write(repository.read.merge(first_name: 'Emma'))

        expect(state_store.first_name).to eq('Emma')
      end

      it 'custom predicate methods work with method_missing attributes' do
        expect(state_store.has_previous_names?).to be true
        expect(state_store.full_name).to eq('Sarah Elizabeth Johnson')
        expect(state_store.age).to be_between(38, 40)
        expect(state_store.uk_resident?).to be true
      end

      it 'does not override custom methods with method_missing' do
        expect(state_store).to respond_to(:full_name)
        expect(state_store).to respond_to(:age)
        expect(state_store.full_name).to include('Sarah')
      end

      it 'raises NoMethodError for undefined attributes' do
        state_store.step_definitions = wizard.step_definitions
        state_store.attribute_names = wizard.attribute_names

        expect { state_store.undefined_attribute }.to raise_error(NoMethodError)
      end
    end

    context 'applicant without previous names' do
      before do
        repository.write({
                           first_name: 'James',
                           last_name: 'Brown',
                           date_of_birth: '1990-07-22',
                           gender: 'male',
                           previous_names: 'no',
                         })

        state_store.step_definitions = wizard.step_definitions
        state_store.attribute_names = wizard.attribute_names
      end

      it 'predicate returns false when previous_names is no' do
        expect(state_store.has_previous_names?).to be false
      end

      it 'previous_names_details attributes return nil via method_missing' do
        expect(state_store.previous_first_name).to be_nil
        expect(state_store.previous_last_name).to be_nil
      end
    end

    context 'partial application (incomplete data)' do
      before do
        repository.write({
                           service_type: 'basic',
                           first_name: 'John',
                           last_name: 'Doe',
                         })

        state_store.step_definitions = wizard.step_definitions
        state_store.attribute_names = wizard.attribute_names
      end

      it 'returns nil for attributes not yet provided' do
        expect(state_store.date_of_birth).to be_nil
        expect(state_store.email).to be_nil
        expect(state_store.passport_number).to be_nil
      end

      it 'returns provided values correctly' do
        expect(state_store.first_name).to eq('John')
        expect(state_store.last_name).to eq('Doe')
        expect(state_store.service_type).to eq('basic')
      end
    end

    context 'integration with wizard initialization' do
      it 'auto-initializes step_definitions and attribute_names during wizard creation' do
        fresh_repository = DfE::Wizard::Repository::InMemory.new
        fresh_state_store = state_store_class.new(repository: fresh_repository)

        fresh_repository.write({ first_name: 'Alice', last_name: 'Smith' })

        wizard_class.new(
          current_step: :personal_details,
          state_store: fresh_state_store,
        )

        expect(fresh_state_store.first_name).to eq('Alice')
        expect(fresh_state_store.last_name).to eq('Smith')
      end

      it 'makes custom predicates work immediately after wizard initialization' do
        fresh_repository = DfE::Wizard::Repository::InMemory.new
        fresh_state_store = state_store_class.new(repository: fresh_repository)

        fresh_repository.write({ previous_names: 'yes' })

        wizard_class.new(
          current_step: :previous_names_question,
          state_store: fresh_state_store,
        )

        expect(fresh_state_store.has_previous_names?).to be true
      end
    end

    context 'real-world usage example' do
      before do
        repository.write({
                           first_name: 'Emma',
                           middle_names: 'Grace',
                           last_name: 'Williams',
                           date_of_birth: '1992-11-08',
                           email: 'emma.williams@example.com',
                           phone: '07700900456',
                           country_of_residence: 'united_kingdom',
                         })

        state_store.step_definitions = wizard.step_definitions
        state_store.attribute_names = wizard.attribute_names
      end

      it 'provides natural attribute access via method_missing' do
        expect(state_store.first_name).to eq('Emma')
        expect(state_store.email).to eq('emma.williams@example.com')
        expect(state_store.full_name).to eq('Emma Grace Williams')
        expect(state_store.uk_resident?).to be true
      end
    end

    context 'when disabled' do
      let(:disabled_store_class) do
        Class.new do
          include DfE::Wizard::Core::StateStore

          def step_attributes_methods?
            false
          end
        end
      end

      let(:disabled_store) { disabled_store_class.new(repository: repository) }

      it 'still responds to method_missing for attributes' do
        repository.write({ first_name: 'Test' })
        disabled_store.step_definitions = wizard.step_definitions
        disabled_store.attribute_names = wizard.attribute_names

        expect {
          disabled_store.first_name
        }.to raise_error(NoMethodError)
      end

      it 'can still access data via read' do
        repository.write({ first_name: 'Manual' })

        expect(disabled_store.read[:first_name]).to eq('Manual')
      end
    end
  end

  describe 'edge cases' do
    context 'with attribute name collisions' do
      let(:collision_store_class) do
        Class.new do
          include DfE::Wizard::Core::StateStore

          def first_name
            'CUSTOM_METHOD'
          end
        end
      end

      let(:collision_store) { collision_store_class.new(repository: repository) }

      it 'preserves existing custom method (method_missing not called)' do
        repository.write({ first_name: 'Sarah' })
        collision_store.step_definitions = wizard.step_definitions
        collision_store.attribute_names = wizard.attribute_names

        expect(collision_store.first_name).to eq('CUSTOM_METHOD')
      end
    end

    context 'with steps that have no attributes' do
      it 'handles Start and CheckAnswers gracefully' do
        state_store.step_definitions = wizard.step_definitions
        state_store.attribute_names = wizard.attribute_names

        expect { state_store.first_name }.not_to raise_error
      end
    end
  end

  describe '#[]' do
    it 'retrieves value by key' do
      state_store.write({ first_name: 'John' })

      expect(state_store[:first_name]).to eq('John')
    end

    it 'returns nil for missing key' do
      expect(state_store[:missing]).to be_nil
    end
  end

  describe '#execute_operation' do
    class TestOp
      def initialize(repository:, step:)
        @repository = repository
        @step = step
      end

      def execute
        @repository.write(executed: true)
        { success: true }
      end
    end

    class TestStep
      include DfE::Wizard::Step
      attribute :name
    end

    it 'executes operation and returns result' do
      step = TestStep.new(name: 'test')
      result = state_store.execute_operation(operation_class: TestOp, step:)

      expect(result[:success]).to be true
    end

    it 'operation can write to repository' do
      step = TestStep.new(name: 'test')
      state_store.execute_operation(operation_class: TestOp, step:)

      expect(state_store.read).to include(executed: true)
    end
  end
end
