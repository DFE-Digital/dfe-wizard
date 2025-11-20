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
          # Define all nodes
          graph.add_node :personal_details, Steps::PersonalDetails
          graph.add_node :account_type, Steps::AccountType
          graph.add_node :company_details, Steps::CompanyDetails
          graph.add_node :verification_method, Steps::VerificationMethod
          graph.add_node :email_verification, Steps::EmailVerification
          graph.add_node :phone_verification, Steps::PhoneVerification
          graph.add_node :id_verification, Steps::IdVerification
          graph.add_node :review, Steps::Review

          # Set entry point
          graph.root :personal_details

          # Linear flow: personal_details → account_type
          graph.add_edge from: :personal_details, to: :account_type

          # Branch 1: account_type conditional
          graph.add_conditional_edge(
            from: :account_type,
            when: :business?,
            then: :company_details,
            else: :verification_method,
            label: 'Business vs Individual',
          )

          # Branch 1 converges: company_details → verification_method
          graph.add_edge from: :company_details, to: :verification_method

          # Branch 2: verification_method multiple branches
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

          # Branch 2 converges: all verification → review
          graph.add_edge from: :email_verification, to: :review
          graph.add_edge from: :phone_verification, to: :review
          graph.add_edge from: :id_verification, to: :review
        end
      end

      def route_strategy
        DfE::Wizard::RouteStrategy::ConfigurableRoutes.new(wizard: self)
      end

      def logger
        DfE::Wizard::Logger.new(nil)
      end

      # Delegate predicates to state_store
      delegate :business?, :individual?,
               :verification_email?, :verification_phone?, :verification_id?,
               to: :state_store
    end
  end

  let(:state_store_class) do
    Class.new do
      include DfE::Wizard::StateStore

      # Account type predicates
      def business?(_step = nil)
        read.dig(:steps, :account_type, :account_type) == 'business'
      end

      def individual?(_step = nil)
        read.dig(:steps, :account_type, :account_type) == 'individual'
      end

      # Verification method predicates
      def verification_email?(_step = nil)
        read.dig(:steps, :verification_method, :verification_type) == 'email'
      end

      def verification_phone?(_step = nil)
        read.dig(:steps, :verification_method, :verification_type) == 'phone'
      end

      def verification_id?(_step = nil)
        read.dig(:steps, :verification_method, :verification_type) == 'id'
      end
    end
  end

  # Test step classes
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

          attribute :code

          validates :code, presence: true
        end

        class PhoneVerification
          include DfE::Wizard::Step

          attribute :code

          validates :code, presence: true
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

  let(:state_store) { state_store_class.new }
  let(:wizard) { wizard_class.new(current_step:, state_store:) }
  let(:current_step) { :personal_details }

  describe '#raw_data' do
    context 'with no saved data' do
      it 'returns empty structure' do
        expect(wizard.raw_data).to eq({})
      end
    end

    context 'with saved data' do
      before do
        state_store.save_steps(
          personal_details: { name: 'John Doe', email: 'john@example.com' },
          account_type: { account_type: 'individual' },
        )
      end

      it 'returns all persisted data' do
        expect(wizard.raw_data[:steps]).to include(
          personal_details: { name: 'John Doe', email: 'john@example.com' },
          account_type: { account_type: 'individual' },
        )
      end
    end

    context 'with data from multiple branches' do
      before do
        state_store.save_steps(
          personal_details: { name: 'Jane', email: 'jane@example.com' },
          account_type: { account_type: 'business' },
          company_details: { company_name: 'ACME', registration_number: '12345' },
          verification_method: { verification_type: 'email' },
          email_verification: { code: '123456' },
          phone_verification: { code: '999999' }, # Orphaned (unreachable)
        )
      end

      it 'returns data from all branches including unreachable ones' do
        expect(wizard.raw_data[:steps].keys).to contain_exactly(
          :personal_details,
          :account_type,
          :company_details,
          :verification_method,
          :email_verification,
          :phone_verification,
        )
      end
    end
  end

  describe '#raw_step_data' do
    before do
      state_store.save_steps(
        personal_details: { name: 'John', email: 'john@example.com' },
      )
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
      state_store.save_steps(phone_verification: { code: '999999' })

      expect(wizard.raw_step_data(:phone_verification)).to eq(code: '999999')
    end
  end

  describe '#step_data_exists?' do
    before do
      state_store.save_steps(personal_details: { name: 'John', email: 'john@example.com' })
    end

    it 'returns true when step has data' do
      expect(wizard.step_data_exists?(:personal_details)).to be true
    end

    it 'returns false when step has no data' do
      expect(wizard.step_data_exists?(:account_type)).to be false
    end

    it 'returns true for unreachable steps with data' do
      state_store.save_steps(phone_verification: { code: '123' })

      expect(wizard.step_data_exists?(:phone_verification)).to be true
    end
  end

  describe '#orphaned_steps_data' do
    context 'with no unreachable data' do
      before do
        state_store.save_steps(
          personal_details: { name: 'John', email: 'john@example.com' },
          account_type: { account_type: 'individual' },
        )
      end

      let(:current_step) { :verification_method }

      it 'returns empty hash' do
        expect(wizard.orphaned_steps_data).to eq({})
      end
    end

    context 'with unreachable branch data' do
      before do
        state_store.save_steps(
          personal_details: { name: 'Jane', email: 'jane@example.com' },
          account_type: { account_type: 'business' },
          company_details: { company_name: 'ACME', registration_number: '12345' },
          verification_method: { verification_type: 'email' },
          email_verification: { code: '111111' },
          phone_verification: { code: '999999' }, # Orphaned
        )
      end

      let(:current_step) { :review }

      it 'returns only unreachable steps' do
        expect(wizard.orphaned_steps_data).to eq(
          phone_verification: { code: '999999' },
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
        # Initial: individual path with email verification
        state_store.save_steps(
          personal_details: { name: 'User', email: 'user@example.com' },
          account_type: { account_type: 'individual' },
          verification_method: { verification_type: 'email' },
          email_verification: { code: '111111' },
        )

        # Change to business (creates orphan)
        state_store.save_steps(
          account_type: { account_type: 'business' },
          company_details: { company_name: 'Corp', registration_number: '99999' },
          verification_method: { verification_type: 'phone' },
          phone_verification: { code: '222222' },
        )
      end

      let(:current_step) { :review }

      it 'detects steps orphaned by branch change' do
        expect(wizard.orphaned_steps_data.keys).to include(:email_verification)
      end
    end
  end

  describe '#data (filtered)' do
    context 'with mixed reachable and unreachable data' do
      before do
        state_store.save_steps(
          personal_details: { name: 'John', email: 'john@example.com' },
          account_type: { account_type: 'individual' },
          verification_method: { verification_type: 'phone' },
          phone_verification: { code: '123456' },
          review: {},
          email_verification: { code: '999999' }, # Orphaned
        )
      end

      let(:current_step) { :review }

      it 'returns only reachable steps' do
        expect(wizard.data[:steps].keys).to contain_exactly(
          :personal_details,
          :account_type,
          :verification_method,
          :phone_verification,
          :review,
        )
      end

      it 'excludes unreachable steps' do
        expect(wizard.data[:steps]).not_to have_key(:email_verification)
      end
    end

    context 'with business path' do
      before do
        state_store.save_steps(
          personal_details: { name: 'Jane', email: 'jane@example.com' },
          account_type: { account_type: 'business' },
          company_details: { company_name: 'ACME', registration_number: '12345' },
          verification_method: { verification_type: 'id' },
          id_verification: { document_number: 'ID123' },
          review: {},
        )
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
          :review,
        )
      end
    end
  end

  describe '#step_data' do
    before do
      state_store.save_steps(
        personal_details: { name: 'John', email: 'john@example.com' },
        account_type: { account_type: 'individual' },
        verification_method: { verification_type: 'email' },
        phone_verification: { code: '999999' }, # Orphaned
      )
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
      expect(wizard.step_data(:email_verification)).to eq({})
    end
  end

  describe '#saved?' do
    before do
      state_store.save_steps(
        personal_details: { name: 'John', email: 'john@example.com' },
        account_type: { account_type: 'individual' },
        phone_verification: { code: '999999' }, # Orphaned
      )
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
        state_store.save_steps(
          personal_details: { name: 'John', email: 'john@example.com' },
          account_type: { account_type: 'individual' },
        )
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
        state_store.save_steps(
          personal_details: { name: 'Jane', email: 'jane@example.com' },
          account_type: { account_type: 'business' },
          company_details: { company_name: 'ACME', registration_number: '12345' },
          verification_method: { verification_type: 'email' },
          email_verification: { code: '123456' },
          review: {},
        )
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
        state_store.save_steps(
          personal_details: { name: 'User', email: 'user@example.com' },
          account_type: { account_type: 'individual' },
          verification_method: { verification_type: 'phone' },
          phone_verification: { code: '123' },
          review: {},
          email_verification: { code: '999' }, # Orphaned
        )
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

  describe '#steps_saved' do
    before do
      state_store.save_steps(
        personal_details: { name: 'John', email: 'john@example.com' },
        account_type: { account_type: 'individual' },
      )
    end

    let(:current_step) { :verification_method }

    it 'returns step objects for saved steps' do
      steps = wizard.steps_saved

      expect(steps).to all(be_a(DfE::Wizard::Step))
      expect(steps.map(&:step_id)).to eq(%i[personal_details account_type])
    end

    it 'hydrates step objects with data' do
      personal_step = wizard.steps_saved.first

      expect(personal_step.name).to eq('John')
      expect(personal_step.email).to eq('john@example.com')
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
      state_store.save_steps(personal_details: { name: 'John', email: 'john@example.com' })

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
      state_store.save_steps(personal_details: { name: 'John', email: 'john@example.com' })
      wizard.set_metadata(:user_id, 999)

      expect(wizard.step_data(:personal_details)).to eq(
        name: 'John',
        email: 'john@example.com',
      )
    end
  end

  describe '#all_metadata' do
    before do
      state_store.save_steps(personal_details: { name: 'John', email: 'john@example.com' })
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

  describe '#save' do
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

    it 'saves current step data' do
      expect(wizard).to be_current_step_valid
      wizard.save

      expect(wizard.raw_step_data(:personal_details).symbolize_keys).to eq(
        name: 'Alice',
        email: 'alice@example.com',
      )
    end

    it 'updates saved_path' do
      expect { wizard.save }.to change { wizard.saved_path }.from([]).to([:personal_details])
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

    it 'deep merges without removing existing data' do
      state_store.save_steps(personal_details: { name: 'John', email: 'john@example.com' })
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
      state_store.save_steps(
        personal_details: { name: 'John', email: 'john@example.com' },
        account_type: { account_type: 'individual' },
      )
      wizard.set_metadata(:user_id, 123)
      wizard.mark_completed
    end

    it 'removes all data' do
      wizard.clear_state

      expect(wizard.raw_data).to eq({})
    end

    it 'removes step data' do
      wizard.clear_state

      expect(wizard.saved_path).to be_empty
    end

    it 'removes metadata' do
      wizard.clear_state

      expect(wizard.get_metadata(:user_id)).to be_nil
    end

    it 'removes completion flags' do
      wizard.clear_state

      expect(wizard.completed?).to be false
    end
  end

  describe 'integration: full wizard flow with branch changes' do
    it 'handles complete individual path' do
      state_store.save_steps(
        personal_details: { name: 'Alice', email: 'alice@example.com' },
        account_type: { account_type: 'individual' },
        verification_method: { verification_type: 'email' },
        email_verification: { code: '123456' },
        review: {},
      )

      wizard_at_review = wizard_class.new(current_step: :review, state_store:)

      expect(wizard_at_review.saved_path).to eq(%i[
                                                  personal_details
                                                  account_type
                                                  verification_method
                                                  email_verification
                                                ])

      expect(wizard_at_review.orphaned_steps_data).to be_empty
    end

    it 'handles branch change creating orphans' do
      state_store.save_steps(
        personal_details: { name: 'Bob', email: 'bob@example.com' },
        account_type: { account_type: 'individual' },
        verification_method: { verification_type: 'email' },
        email_verification: { code: '111111' },
      )

      state_store.save_steps(
        account_type: { account_type: 'business' },
        company_details: { company_name: 'Corp', registration_number: '99999' },
        verification_method: { verification_type: 'phone' },
        phone_verification: { code: '222222' },
        review: {},
      )

      wizard_at_review = wizard_class.new(current_step: :review, state_store:)

      expect(wizard_at_review.saved_path).to eq(%i[
                                                  personal_details
                                                  account_type
                                                  company_details
                                                  verification_method
                                                  phone_verification
                                                ])

      expect(wizard_at_review.orphaned_steps_data).to eq(
        email_verification: { code: '111111' },
      )
    end

    it 'preserves metadata through branch changes' do
      wizard.set_metadata(:user_id, 789)
      wizard.set_metadata(:started_at, Time.current)

      state_store.save_steps(
        personal_details: { name: 'Charlie', email: 'charlie@example.com' },
        account_type: { account_type: 'individual' },
      )

      state_store.save_steps(account_type: { account_type: 'business' })

      expect(wizard.get_metadata(:user_id)).to eq(789)
      expect(wizard.get_metadata(:started_at)).to be_present
    end
  end
end
