# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DfE::Wizard::Core::StateManagement do
  # ============================================================================
  # WIZARD GRAPH STRUCTURE EXAMPLE
  # ============================================================================
  #
  # Registration Wizard Flow:
  #
  #   [start]
  #      ↓
  #   personal_details (name, email)
  #      ↓
  #   account_type (individual/business)
  #      ├─ individual → verification_method
  #      └─ business → company_details
  #                       ↓
  #                    verification_method
  #      ↓
  #   verification_method (email/phone/id)
  #      ├─ email → email_verification
  #      ├─ phone → phone_verification
  #      └─ id → id_verification
  #      ↓
  #   review
  #      ↓
  #   [complete]
  #
  # ============================================================================

  let(:wizard_class) do
    Class.new do
      include DfE::Wizard

      def steps_processor
        DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
          graph.add_node :personal_details, Steps::PersonalDetails
          graph.add_node :account_type, Steps::AccountType
          graph.add_node :company_details, Steps::CompanyDetails
          graph.add_node :verification_method, Steps::VerificationMethod
          graph.add_node :email_verification, Steps::EmailVerification
          graph.add_node :phone_verification, Steps::PhoneVerification
          graph.add_node :id_verification, Steps::IdVerification
          graph.add_node :review, Steps::Review

          graph.root :personal_details

          graph.add_edge from: :personal_details, to: :account_type

          graph.add_conditional_edge(
            from: :account_type,
            when: :business?,
            then: :company_details,
            else: :verification_method,
            label: 'Business vs Individual',
          )

          graph.add_edge from: :company_details, to: :verification_method

          graph.add_multiple_conditional_edges(
            from: :verification_method,
            branches: [
              { when: :verification_email?, then: :email_verification },
              { when: :verification_phone?, then: :phone_verification },
              { when: :verification_id?, then: :id_verification },
            ],
            default: :review,
            label: 'Verification Method',
          )

          graph.add_edge from: :email_verification, to: :review
          graph.add_edge from: :phone_verification, to: :review
          graph.add_edge from: :id_verification, to: :review
        end
      end

      def steps_operator
        DfE::Wizard::StepsOperator::Builder.draw(wizard: self, callable: state_store) do |_builder|
          # Use defaults: [Validate, Persist] for all steps
        end
      end

      def route_strategy
        DfE::Wizard::RouteStrategy::ConfigurableRoutes.new(wizard: self)
      end

      def logger
        DfE::Wizard::Logger.new(nil)
      end

      delegate :business?, :individual?,
               :verification_email?, :verification_phone?, :verification_id?,
               to: :state_store
    end
  end

  let(:state_store_class) do
    Class.new do
      include DfE::Wizard::Core::StateStore

      def business?(_step = nil)
        account_type == 'business'
      end

      def individual?(_step = nil)
        account_type == 'individual'
      end

      def verification_email?(_step = nil)
        verification_type == 'email'
      end

      def verification_phone?(_step = nil)
        verification_type == 'phone'
      end

      def verification_id?(_step = nil)
        verification_type == 'id'
      end
    end
  end

  before(:all) do
    unless defined?(Steps::PersonalDetails)
      module Steps
        class PersonalDetails
          include DfE::Wizard::Step

          attribute :name
          attribute :email

          validates :name, :email, presence: true
        end

        class AccountType
          include DfE::Wizard::Step

          attribute :account_type

          validates :account_type, presence: true, inclusion: { in: %w[individual business] }
        end

        class CompanyDetails
          include DfE::Wizard::Step

          attribute :company_name
          attribute :registration_number

          validates :company_name, :registration_number, presence: true
        end

        class VerificationMethod
          include DfE::Wizard::Step

          attribute :verification_type

          validates :verification_type, presence: true, inclusion: { in: %w[email phone id] }
        end

        class EmailVerification
          include DfE::Wizard::Step

          attribute :email_code

          validates :email_code, presence: true
        end

        class PhoneVerification
          include DfE::Wizard::Step

          attribute :phone_code

          validates :phone_code, presence: true
        end

        class IdVerification
          include DfE::Wizard::Step

          attribute :document_number

          validates :document_number, presence: true
        end

        class Review
          include DfE::Wizard::Step
        end
      end
    end
  end

  let(:repository) { DfE::Wizard::Repository::InMemory.new }
  let(:state_store) { state_store_class.new(repository: repository) }
  let(:wizard) { wizard_class.new(current_step:, state_store:) }
  let(:current_step) { :personal_details }

  describe '#raw_data' do
    context 'with no saved data' do
      it 'returns empty structure with steps key' do
        expect(wizard.raw_data).to eq({ steps: {} })
      end
    end

    context 'with saved data' do
      before do
        repository.write({
                           name: 'John Doe',
                           email: 'john@example.com',
                           account_type: 'individual',
                         })
      end

      it 'returns nested structure with steps grouped by step_id' do
        data = wizard.raw_data

        expect(data[:steps]).to include(
          personal_details: { name: 'John Doe', email: 'john@example.com' },
          account_type: { account_type: 'individual' },
        )
      end
    end

    context 'with data from multiple branches' do
      before do
        repository.write({
                           name: 'Jane',
                           email: 'jane@example.com',
                           account_type: 'business',
                           company_name: 'ACME',
                           registration_number: '12345',
                           verification_type: 'email',
                           email_code: '123456',
                         })
      end

      it 'returns all steps including unreachable ones' do
        data = wizard.raw_data

        expect(data[:steps].keys).to contain_exactly(
          :personal_details,
          :account_type,
          :company_details,
          :verification_method,
          :email_verification,
        )
      end
    end
  end

  describe '#raw_step_data' do
    before do
      repository.write({
                         name: 'John',
                         email: 'john@example.com',
                       })
    end

    it 'returns data for existing step' do
      expect(wizard.raw_step_data(:personal_details)).to eq(
        name: 'John',
        email: 'john@example.com',
      )
    end

    it 'returns empty hash for non-existent step' do
      expect(wizard.raw_step_data(:nonexistent)).to eq({})
    end

    it 'returns data even for unreachable steps' do
      repository.write({ phone_code: '999999' })

      expect(wizard.raw_step_data(:phone_verification)).to eq(phone_code: '999999')
    end
  end

  describe '#step_data_exists?' do
    before do
      repository.write({ name: 'John', email: 'john@example.com' })
    end

    it 'returns true when step has data' do
      expect(wizard.step_data_exists?(:personal_details)).to be true
    end

    it 'returns false when step has no data' do
      expect(wizard.step_data_exists?(:account_type)).to be false
    end

    it 'returns true for unreachable steps with data' do
      repository.write({ phone_code: '123' })

      expect(wizard.step_data_exists?(:phone_verification)).to be true
    end
  end

  describe '#orphaned_steps_data' do
    context 'with no unreachable data' do
      before do
        repository.write({
                           name: 'John',
                           email: 'john@example.com',
                           account_type: 'individual',
                         })
      end

      let(:current_step) { :verification_method }

      it 'returns empty hash' do
        expect(wizard.orphaned_steps_data).to eq({})
      end
    end

    context 'with unreachable branch data' do
      before do
        repository.write({
                           name: 'Jane',
                           email: 'jane@example.com',
                           account_type: 'business',
                           company_name: 'ACME',
                           registration_number: '12345',
                           verification_type: 'email',
                           email_code: '111111',
                           phone_code: '999999',
                         })
      end

      let(:current_step) { :review }

      it 'returns only unreachable steps' do
        orphaned = wizard.orphaned_steps_data

        expect(orphaned).to eq(
          phone_verification: { phone_code: '999999' },
        )
      end

      it 'does not include steps in current flow' do
        expect(wizard.orphaned_steps_data.keys).not_to include(
          :personal_details,
          :account_type,
          :company_details,
          :verification_method,
          :email_verification,
        )
      end
    end

    context 'when user changes branch creating orphans' do
      before do
        repository.write({
                           name: 'User',
                           email: 'user@example.com',
                           account_type: 'individual',
                           verification_type: 'email',
                           email_code: '111111',
                         })

        repository.write(repository.read.merge(
                           account_type: 'business',
                           company_name: 'Corp',
                           registration_number: '99999',
                         ))

        repository.write(repository.read.merge(
                           verification_type: 'phone',
                           phone_code: '222222',
                         ))
      end

      let(:current_step) { :review }

      it 'detects steps orphaned by branch change' do
        orphaned = wizard.orphaned_steps_data

        expect(orphaned).to include(:email_verification)
        expect(orphaned[:email_verification]).to eq(email_code: '111111')
      end
    end
  end

  describe '#data (filtered)' do
    context 'with mixed reachable and unreachable data' do
      before do
        repository.write({
                           name: 'John',
                           email: 'john@example.com',
                           account_type: 'individual',
                           verification_type: 'phone',
                           phone_code: '123456',
                           email_code: '999999',
                         })
      end

      let(:current_step) { :review }

      it 'returns only reachable steps' do
        filtered = wizard.data

        expect(filtered[:steps].keys).to contain_exactly(
          :personal_details,
          :account_type,
          :verification_method,
          :phone_verification,
        )
      end

      it 'excludes unreachable steps' do
        expect(wizard.data[:steps]).not_to have_key(:email_verification)
        expect(wizard.data[:steps]).not_to have_key(:id_verification)
      end
    end

    context 'with business path' do
      before do
        repository.write({
                           name: 'Jane',
                           email: 'jane@example.com',
                           account_type: 'business',
                           company_name: 'ACME',
                           registration_number: '12345',
                           verification_type: 'id',
                           document_number: 'ID123',
                         })
      end

      let(:current_step) { :review }

      it 'includes business-specific steps' do
        expect(wizard.data[:steps]).to include(:company_details)
      end

      it 'follows business → company → verification → review path' do
        expect(wizard.data[:steps].keys).to contain_exactly(
          :personal_details,
          :account_type,
          :company_details,
          :verification_method,
          :id_verification,
        )
      end
    end
  end

  describe '#step_data' do
    before do
      repository.write({
                         name: 'John',
                         email: 'john@example.com',
                         account_type: 'individual',
                         verification_type: 'email',
                         email_code: '123456',
                         phone_code: '999999',
                       })
    end

    let(:current_step) { :email_verification }

    it 'returns data for reachable steps' do
      expect(wizard.step_data(:personal_details)).to eq(
        name: 'John',
        email: 'john@example.com',
      )
    end

    it 'returns {} for unreachable steps' do
      expect(wizard.step_data(:phone_verification)).to eq({})
    end

    it 'returns {} for steps with no data' do
      expect(wizard.step_data(:review)).to eq({})
    end
  end

  describe '#saved?' do
    before do
      repository.write({
                         name: 'John',
                         email: 'john@example.com',
                         account_type: 'individual',
                         phone_code: '999999', # Orphaned
                       })
    end

    let(:current_step) { :verification_method }

    it 'returns true for reachable steps with data' do
      expect(wizard.saved?(:personal_details)).to be true
      expect(wizard.saved?(:account_type)).to be true
    end

    it 'returns false for unreachable steps even with data' do
      expect(wizard.saved?(:phone_verification)).to be false
    end

    it 'returns false for reachable steps without data' do
      expect(wizard.saved?(:verification_method)).to be false
    end
  end

  describe '#saved_path' do
    context 'with partial completion' do
      before do
        repository.write({
                           name: 'John',
                           email: 'john@example.com',
                           account_type: 'individual',
                         })
      end

      let(:current_step) { :verification_method }

      it 'returns steps with data in flow order' do
        expect(wizard.saved_path).to eq(%i[personal_details account_type])
      end

      it 'excludes future steps without data' do
        expect(wizard.saved_path).not_to include(:verification_method)
      end
    end

    context 'with complete flow' do
      before do
        repository.write({
                           name: 'Jane',
                           email: 'jane@example.com',
                           account_type: 'business',
                           company_name: 'ACME',
                           registration_number: '12345',
                           verification_type: 'email',
                           email_code: '123456',
                         })
      end

      let(:current_step) { :review }

      it 'returns all steps in business path' do
        expect(wizard.saved_path).to eq(%i[
                                          personal_details
                                          account_type
                                          company_details
                                          verification_method
                                          email_verification
                                        ])
      end
    end

    context 'with orphaned data' do
      before do
        repository.write({
                           name: 'User',
                           email: 'user@example.com',
                           account_type: 'individual',
                           verification_type: 'phone',
                           phone_code: '123',
                           email_code: '999',
                         })
      end

      let(:current_step) { :review }

      it 'excludes orphaned steps' do
        expect(wizard.saved_path).not_to include(:email_verification)
      end

      it 'includes only current flow steps' do
        expect(wizard.saved_path).to eq(%i[
                                          personal_details
                                          account_type
                                          verification_method
                                          phone_verification
                                        ])
      end
    end
  end

  describe '#mark_completed' do
    it 'sets completed flag' do
      expect { wizard.mark_completed }.to change { wizard.completed? }.from(false).to(true)
    end

    it 'sets completed_at timestamp' do
      wizard.mark_completed
      expect(wizard.completed_at).to be_within(2.seconds).of(Time.current)
    end

    it 'preserves wizard data' do
      repository.write({ name: 'John', email: 'john@example.com' })

      wizard.mark_completed

      expect(wizard.raw_data[:steps][:personal_details]).to eq(
        name: 'John',
        email: 'john@example.com',
      )
    end
  end

  describe '#completed?' do
    it 'returns false initially' do
      expect(wizard.completed?).to be false
    end

    it 'returns true after mark_completed' do
      wizard.mark_completed
      expect(wizard.completed?).to be true
    end
  end

  describe '#completed_at' do
    it 'returns nil initially' do
      expect(wizard.completed_at).to be_nil
    end

    it 'returns timestamp after mark_completed' do
      wizard.mark_completed
      expect(wizard.completed_at).to be_within(2.seconds).of(Time.current)
    end
  end

  describe '#set_metadata and #get_metadata' do
    it 'stores and retrieves metadata' do
      wizard.set_metadata(:user_id, 123)

      expect(wizard.get_metadata(:user_id)).to eq(123)
    end

    it 'supports multiple metadata keys' do
      wizard.set_metadata(:user_id, 123)
      wizard.set_metadata(:ip_address, '192.168.1.1')
      wizard.set_metadata(:session_id, 'abc123')

      expect(wizard.get_metadata(:user_id)).to eq(123)
      expect(wizard.get_metadata(:ip_address)).to eq('192.168.1.1')
      expect(wizard.get_metadata(:session_id)).to eq('abc123')
    end

    it 'returns default when key not found' do
      expect(wizard.get_metadata(:missing, default: 'N/A')).to eq('N/A')
    end

    it 'does not interfere with step data' do
      repository.write({ name: 'John', email: 'john@example.com' })
      wizard.set_metadata(:user_id, 999)

      expect(wizard.step_data(:personal_details)).to eq(
        name: 'John',
        email: 'john@example.com',
      )
    end
  end

  describe '#all_metadata' do
    before do
      repository.write({ name: 'John', email: 'john@example.com' })
      wizard.set_metadata(:user_id, 123)
      wizard.set_metadata(:ip_address, '192.168.1.1')
      wizard.mark_completed
    end

    it 'returns all non-step data' do
      metadata = wizard.all_metadata

      expect(metadata).to include(
        user_id: 123,
        ip_address: '192.168.1.1',
        completed: true,
      )
    end

    it 'excludes steps key' do
      expect(wizard.all_metadata).not_to have_key(:steps)
    end
  end

  describe '#save_current_step with operations pipeline' do
    context 'with valid step' do
      let(:current_step) { :personal_details }
      let(:current_step_params) do
        {
          personal_details: {
            name: 'Alice',
            email: 'alice@example.com',
          },
        }
      end
      let(:wizard) { wizard_class.new(current_step:, state_store:, current_step_params:) }

      it 'runs Validate and Persist operations' do
        expect(wizard.current_step).to be_valid
        result = wizard.save_current_step

        expect(result).to be true
      end

      it 'persists step data to repository' do
        wizard.save_current_step

        expect(wizard.raw_step_data(:personal_details).symbolize_keys).to eq(
          name: 'Alice',
          email: 'alice@example.com',
        )
      end

      it 'updates saved_path' do
        expect { wizard.save_current_step }.to change { wizard.saved_path }.from([]).to([:personal_details])
      end
    end

    context 'with invalid step' do
      let(:current_step) { :personal_details }
      let(:current_step_params) do
        {
          personal_details: {
            name: '',
            email: '',
          },
        }
      end
      let(:wizard) { wizard_class.new(current_step:, state_store:, current_step_params:) }

      it 'returns false without persisting' do
        result = wizard.save_current_step

        expect(result).to be false
      end

      it 'does not persist invalid data' do
        wizard.save_current_step

        expect(wizard.saved_path).to be_empty
      end
    end
  end

  describe '#write_state' do
    it 'merges data into state' do
      wizard.write_state(custom_flag: true, version: 2)

      expect(wizard.raw_data).to include(
        custom_flag: true,
        version: 2,
      )
    end

    it 'merges without removing existing data' do
      repository.write({ name: 'John', email: 'john@example.com' })
      wizard.write_state(user_id: 999)

      expect(wizard.raw_data[:steps][:personal_details]).to eq(
        name: 'John',
        email: 'john@example.com',
      )
      expect(wizard.raw_data[:user_id]).to eq(999)
    end
  end

  describe '#clear_state' do
    before do
      repository.write({
                         name: 'John',
                         email: 'john@example.com',
                         account_type: 'individual',
                       })
      wizard.set_metadata(:user_id, 123)
      wizard.mark_completed
    end

    it 'removes all data' do
      wizard.clear_state

      expect(wizard.raw_data).to eq({ steps: {} })
    end

    it 'removes step data' do
      wizard.clear_state

      expect(wizard.saved_path).to be_empty
    end

    it 'removes metadata' do
      wizard.clear_state

      expect(wizard.get_metadata(:user_id)).to be_nil
    end

    it 'clears completion flag' do
      wizard.clear_state

      expect(wizard.completed?).to be false
    end
  end

  describe '#steps_operator' do
    describe 'default behavior (no explicit configuration)' do
      let(:minimal_wizard_class) do
        Class.new do
          include DfE::Wizard

          def steps_processor
            DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
              graph.add_node :step_one, Steps::PersonalDetails
              graph.add_node :step_two, Steps::AccountType
              graph.root :step_one
              graph.add_edge from: :step_one, to: :step_two
            end
          end

          # DON'T define steps_operator - use default!

          def route_strategy
            DfE::Wizard::RouteStrategy::ConfigurableRoutes.new(wizard: self)
          end

          def logger
            DfE::Wizard::Logger.new(nil)
          end
        end
      end

      let(:minimal_wizard) { minimal_wizard_class.new(current_step: :step_one, state_store:) }

      it 'returns a StepsOperator::Builder instance' do
        expect(minimal_wizard.steps_operator).to be_a(DfE::Wizard::StepsOperator::Builder)
      end

      it 'applies default [Validate, Persist] for all steps' do
        operations = minimal_wizard.steps_operator.operations_for(:step_one)

        expect(operations).to eq([
                                   DfE::Wizard::Operations::Validate,
                                   DfE::Wizard::Operations::Persist,
                                 ])
      end

      it 'applies same defaults for other steps' do
        operations = minimal_wizard.steps_operator.operations_for(:step_two)

        expect(operations).to eq([
                                   DfE::Wizard::Operations::Validate,
                                   DfE::Wizard::Operations::Persist,
                                 ])
      end

      it 'caches the instance (memoization)' do
        first_call = minimal_wizard.steps_operator
        second_call = minimal_wizard.steps_operator

        expect(first_call).to be(second_call)
      end
    end

    describe 'with custom per-step operations' do
      let(:custom_operator_wizard_class) do
        Class.new do
          include DfE::Wizard

          def steps_processor
            DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
              graph.add_node :validate_step, Steps::PersonalDetails
              graph.add_node :payment_step, Steps::AccountType
              graph.add_node :review_step, Steps::CompanyDetails
              graph.root :validate_step
              graph.add_edge from: :validate_step, to: :payment_step
              graph.add_edge from: :payment_step, to: :review_step
            end
          end

          def steps_operator
            DfE::Wizard::StepsOperator::Builder.draw(wizard: self, callable: state_store) do |b|
              b.on_step(:validate_step, use: [DfE::Wizard::Operations::Validate])
              b.on_step(:payment_step, use: [
                          DfE::Wizard::Operations::Validate,
                          ProcessPayment,
                          DfE::Wizard::Operations::Persist,
                        ])
              b.on_step(:review_step, use: []) # Skip operations for review
            end
          end

          def route_strategy
            DfE::Wizard::RouteStrategy::ConfigurableRoutes.new(wizard: self)
          end

          def logger
            DfE::Wizard::Logger.new(nil)
          end
        end
      end

      # Mock custom operation
      class ProcessPayment
        def execute
          { success: true }
        end

        def rollback; end
      end

      let(:custom_wizard) { custom_operator_wizard_class.new(current_step: :validate_step, state_store:) }

      it 'uses only Validate for validate_step' do
        operations = custom_wizard.steps_operator.operations_for(:validate_step)

        expect(operations).to eq([DfE::Wizard::Operations::Validate])
      end

      it 'uses custom pipeline for payment_step' do
        operations = custom_wizard.steps_operator.operations_for(:payment_step)

        expect(operations).to eq([
                                   DfE::Wizard::Operations::Validate,
                                   ProcessPayment,
                                   DfE::Wizard::Operations::Persist,
                                 ])
      end

      it 'skips operations for review_step' do
        operations = custom_wizard.steps_operator.operations_for(:review_step)

        expect(operations).to be_empty
      end
    end

    describe 'fallback to defaults for unconfigured steps' do
      let(:partial_config_wizard_class) do
        Class.new do
          include DfE::Wizard

          def steps_processor
            DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
              graph.add_node :configured_step, Steps::PersonalDetails
              graph.add_node :unconfigured_step, Steps::AccountType
              graph.root :configured_step
              graph.add_edge from: :configured_step, to: :unconfigured_step
            end
          end

          def steps_operator
            DfE::Wizard::StepsOperator::Builder.draw(wizard: self, callable: state_store) do |b|
              b.on_step(:configured_step, use: [DfE::Wizard::Operations::Validate])
              # unconfigured_step NOT explicitly configured
            end
          end

          def route_strategy
            DfE::Wizard::RouteStrategy::ConfigurableRoutes.new(wizard: self)
          end

          def logger
            DfE::Wizard::Logger.new(nil)
          end
        end
      end

      let(:partial_wizard) { partial_config_wizard_class.new(current_step: :configured_step, state_store:) }

      it 'uses custom operations for configured step' do
        operations = partial_wizard.steps_operator.operations_for(:configured_step)

        expect(operations).to eq([DfE::Wizard::Operations::Validate])
      end

      it 'falls back to defaults for unconfigured steps' do
        operations = partial_wizard.steps_operator.operations_for(:unconfigured_step)

        expect(operations).to eq([
                                   DfE::Wizard::Operations::Validate,
                                   DfE::Wizard::Operations::Persist,
                                 ])
      end
    end

    describe 'with only Validate operation' do
      let(:validate_only_wizard_class) do
        Class.new do
          include DfE::Wizard

          def steps_processor
            DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
              graph.add_node :step_one, Steps::PersonalDetails
              graph.root :step_one
            end
          end

          def steps_operator
            DfE::Wizard::StepsOperator::Builder.draw(wizard: self, callable: state_store) do |b|
              b.on_step(:step_one, use: [DfE::Wizard::Operations::Validate])
            end
          end

          def route_strategy
            DfE::Wizard::RouteStrategy::ConfigurableRoutes.new(wizard: self)
          end

          def logger
            DfE::Wizard::Logger.new(nil)
          end
        end
      end

      let(:validate_only_wizard) { validate_only_wizard_class.new(current_step: :step_one, state_store:) }

      it 'returns only Validate operation' do
        operations = validate_only_wizard.steps_operator.operations_for(:step_one)

        expect(operations).to eq([DfE::Wizard::Operations::Validate])
      end

      it 'does not include Persist' do
        operations = validate_only_wizard.steps_operator.operations_for(:step_one)

        expect(operations).not_to include(DfE::Wizard::Operations::Persist)
      end
    end

    describe '#save_current_step with default operations' do
      let(:minimal_wizard_class) do
        Class.new do
          include DfE::Wizard

          def steps_processor
            DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
              graph.add_node :step_one, Steps::PersonalDetails
              graph.root :step_one
            end
          end

          def route_strategy
            DfE::Wizard::RouteStrategy::ConfigurableRoutes.new(wizard: self)
          end

          def logger
            DfE::Wizard::Logger.new(nil)
          end
        end
      end

      context 'with valid step and default operations' do
        let(:current_step) { :step_one }
        let(:current_step_params) do
          {
            step_one: {
              name: 'Bob',
              email: 'bob@example.com',
            },
          }
        end
        let(:minimal_wizard) do
          minimal_wizard_class.new(current_step:, state_store:, current_step_params:)
        end

        it 'runs default Validate then Persist' do
          expect(minimal_wizard.current_step).to be_valid
          result = minimal_wizard.save_current_step

          expect(result).to be true
        end

        it 'persists with default pipeline' do
          minimal_wizard.save_current_step

          expect(minimal_wizard.raw_step_data(:step_one).symbolize_keys).to eq(
            name: 'Bob',
            email: 'bob@example.com',
          )
        end
      end

      context 'with invalid step and default operations' do
        let(:current_step) { :step_one }
        let(:current_step_params) do
          {
            step_one: {
              name: '',
              email: '',
            },
          }
        end
        let(:minimal_wizard) do
          minimal_wizard_class.new(current_step:, state_store:, current_step_params:)
        end

        it 'stops at Validate (does not persist)' do
          result = minimal_wizard.save_current_step

          expect(result).to be false
        end

        it 'does not persist invalid data' do
          minimal_wizard.save_current_step

          expect(minimal_wizard.saved_path).to be_empty
        end
      end
    end
  end
end
