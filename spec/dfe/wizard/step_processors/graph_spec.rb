RSpec.describe DfE::Wizard::StepsProcessor::Graph, 'Waste Exemption Wizard Graph' do
  # Waste Exemption Wizard - DEFRA use case
  # Simplified from: https://github.com/DEFRA/waste-exemptions-engine
  #
  # This wizard determines the waste exemption application path based on:
  # - Organization type (simple edge)
  # - Waste category (conditional edge)
  # - Activity type (multiple conditional edge)
  # - Application status (custom branching edge)
  class WasteExemptionWizard
    include DfE::Wizard

    delegate :is_upper_tier_waste?,
             :is_listed_activity?,
             :is_non_listed_activity?,
             :is_exempt_activity?,
             :account_feature_flag_enabled?,
             to: :state_store

    def initialize
      @state_store = WasteStateStore.new
      @current_step_name = :organization_type
    end

    def steps_processor
      DfE::Wizard::StepsProcessor::Graph.draw(self) do |g|
        # Nodes
        g.add_node :organization_type, Steps::OrganizationType, label: 'Organization Type'
        g.add_node :account_login, Steps::AccountLogin, label: 'Account Login'
        g.add_node :waste_category, Steps::WasteCategory, label: 'Waste Category'
        g.add_node :activity_type, Steps::ActivityType, label: 'Activity Type'
        g.add_node :office_address, Steps::OfficeAddress, label: 'Office Address'
        g.add_node :review, Steps::Review, label: 'Review Application'
        g.add_node :issue_certificate, Steps::IssueCertificate, label: 'Issue Certificate'
        g.add_node :rejection_notice, Steps::RejectionNotice, label: 'Rejection Notice'
        g.add_node :pending_info, Steps::PendingInfo, label: 'Pending Information'

        g.add_node :account_show, DfE::Wizard::Redirect, skip_when: :account_feature_flag_enabled?

        # Dynamic root: returning users go to login, new users to organization type
        g.conditional_root(potential_root: %i[account_login organization_type]) do |state|
          state.is_returning_user? ? :account_login : :organization_type
        end

        # Simple edges (linear progression)
        g.add_edge from: :organization_type, to: :waste_category
        g.add_edge from: :account_login, to: :waste_category

        # Conditional edge (if/else): upper tier vs lower tier waste
        g.add_conditional_edge(
          from: :waste_category,
          when: :is_upper_tier_waste?,
          then: :activity_type,
          else: :office_address,
          label: 'Upper tier waste?',
        )

        # Multiple conditional edges (N-way branching): 3 activity paths
        g.add_multiple_conditional_edges(
          from: :activity_type,
          branches: [
            { when: :is_listed_activity?, then: :office_address, label: 'Listed Activity' },
            { when: :is_non_listed_activity?, then: :office_address, label: 'Non-listed Activity' },
            { when: :is_exempt_activity?, then: :review, label: 'Exempt Activity' },
          ],
          default: :office_address,
          label: 'Activity Classification',
        )

        # Simple edge continuation
        g.add_edge from: :office_address, to: :review

        # Custom branching edge: application status determines path
        g.add_custom_branching_edge(
          from: :review,
          conditional: :determine_status_path,
          potential_transitions: [
            { label: 'Submitted', nodes: [:review] },
            { label: 'Approved', nodes: [:issue_certificate] },
            { label: 'Rejected', nodes: [:rejection_notice] },
            { label: 'Pending', nodes: [:pending_info] },
          ],
        )
      end
    end

    def logger
      DfE::Wizard::Logger.new(Rails.logger)
    end

    def determine_status_path(_step_obj)
      case state_store.application_status
      when :submitted
        :review
      when :approved
        :issue_certificate
      when :rejected
        :rejection_notice
      else
        :pending_info
      end
    end

    def conditional_entry_point
      state_store.is_returning_user? ? :account_login : :organization_type
    end

    class WasteStateStore
      include DfE::Wizard::StateStore

      attr_accessor :waste_category, :activity_type, :application_status, :is_returning_user

      def initialize
        @waste_category = :upper_tier
        @activity_type = :listed
        @application_status = :submitted
        @is_returning_user = false
        @account_feature_flag_enabled = false

        super
      end

      def is_returning_user?
        @is_returning_user.present?
      end

      def is_upper_tier_waste?
        @waste_category == :upper_tier
      end

      def is_lower_tier_waste?
        @waste_category == :lower_tier
      end

      def is_listed_activity?
        @activity_type == :listed
      end

      def is_non_listed_activity?
        @activity_type == :non_listed
      end

      def is_exempt_activity?
        @activity_type == :exempt
      end

      def account_feature_flag_enabled?
        @account_feature_flag_enabled.present?
      end
    end
  end

  # rubocop:disable Lint/EmptyClass
  module Steps
    class ConditionalEntry; end
    class OrganizationType; end
    class AccountLogin; end
    class WasteCategory; end
    class ActivityType; end
    class OfficeAddress; end
    class Review; end
    class IssueCertificate; end
    class RejectionNotice; end
    class PendingInfo; end
  end
  # rubocop:enable Lint/EmptyClass

  subject(:graph) do
    wizard.steps_processor
  end

  let(:wizard) { WasteExemptionWizard.new }

  describe '#root_step' do
    context 'with conditional root (dynamic)' do
      it 'returns entry point for new users' do
        wizard.state_store.is_returning_user = false
        expect(graph.root_step).to eq(:organization_type)
      end

      it 'returns login for returning users' do
        wizard.state_store.is_returning_user = true
        expect(graph.root_step).to eq(:account_login)
      end
    end

    context 'when not passing potential root' do
      before do
        class GraphWithoutPotentialRoot
          def steps_processor
            DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
              graph.add_node :first_page, Object
              graph.add_node :second_page, Object

              graph.conditional_root { %i[first_page second_page].rand }
            end
          end
        end
      end

      it 'raises error without potential root steps' do
        expect {
          GraphWithoutPotentialRoot.new.steps_processor
        }.to raise_error(
          /conditional_root requires :potential_root list of possible entry points for documentation/,
        )
      end
    end
  end

  describe '#next_step' do
    context 'with simple edges' do
      it 'navigates through linear progression' do
        wizard.current_step_name = :organization_type
        expect(graph.next_step(:organization_type)).to eq(:waste_category)
      end
    end

    context 'with conditional edge' do
      it 'routes to activity_type for upper tier waste' do
        wizard.state_store.waste_category = :upper_tier
        expect(graph.next_step(:waste_category)).to eq(:activity_type)
      end

      it 'routes to office_address for lower tier waste' do
        wizard.state_store.waste_category = :lower_tier
        expect(graph.next_step(:waste_category)).to eq(:office_address)
      end
    end

    context 'with multiple conditional edges' do
      it 'routes to office_address for listed activity' do
        wizard.state_store.activity_type = :listed
        expect(graph.next_step(:activity_type)).to eq(:office_address)
      end

      it 'routes to review for exempt activity' do
        wizard.state_store.activity_type = :exempt
        expect(graph.next_step(:activity_type)).to eq(:review)
      end
    end

    context 'with custom branching edge' do
      it 'routes to review for submitted status' do
        wizard.state_store.application_status = :submitted
        expect(graph.next_step(:review)).to eq(:review)
      end

      it 'routes to issue_certificate for approved status' do
        wizard.state_store.application_status = :approved
        expect(graph.next_step(:review)).to eq(:issue_certificate)
      end

      it 'routes to rejection_notice for rejected status' do
        wizard.state_store.application_status = :rejected
        expect(graph.next_step(:review)).to eq(:rejection_notice)
      end

      it 'routes to pending_info for unknown status' do
        wizard.state_store.application_status = :unknown
        expect(graph.next_step(:review)).to eq(:pending_info)
      end
    end

    it 'returns nil when no outgoing edge' do
      expect(graph.next_step(:issue_certificate)).to be_nil
    end

    context 'when skipping steps' do
      before do
        class GraphWithSkippedSteps
          include DfE::Wizard

          delegate :user_not_permitted?, :single_provider?, to: :state_store

          def steps_processor
            DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
              graph.add_node :first_page, Object
              graph.add_node :second_page, Object, skip_when: :user_not_permitted?
              graph.add_node :third_page, Object, skip_when: :single_provider?
              graph.add_node :fourth_page, Object

              graph.add_edge from: :first_page, to: :second_page
              graph.add_edge from: :second_page, to: :third_page
              graph.add_edge from: :third_page, to: :fourth_page

              graph.root :first_page
            end
          end
        end

        class GraphWithSkippedStateStore
          include DfE::Wizard::StateStore

          attr_reader :user, :providers

          def initialize(
            user:, providers:, repository: DfE::Wizard::Repository::InMemory.new,
            attribute_names: [],
            step_definitions: []
          )
            @user = user
            @providers = providers

            super(repository:, attribute_names:, step_definitions:)
          end

          def user_not_permitted?
            !user.permitted?
          end

          def single_provider?
            providers.size == 1
          end
        end
      end

      it 'skip second step when user not permitted but has multiple providers' do
        current_step = :first_page
        state_store = GraphWithSkippedStateStore.new(user: double(permitted?: false), providers: [1, 2])
        graph = GraphWithSkippedSteps.new(state_store:, current_step:).steps_processor

        expect(graph.next_step).to eq(:third_page)
        expect(graph.path_traversal(:fourth_page)).to eq(%i[first_page third_page fourth_page])
      end

      it 'does not skip second step when user is permitted' do
        current_step = :first_page
        state_store =  GraphWithSkippedStateStore.new(user: double(permitted?: true), providers: [1, 2])
        graph = GraphWithSkippedSteps.new(state_store:, current_step:).steps_processor

        expect(graph.next_step).to eq(:second_page)
        expect(graph.path_traversal(:fourth_page)).to eq(%i[first_page second_page third_page fourth_page])
      end

      it 'skip second step when user does not have permissions' do
        current_step = :second_page
        state_store =  GraphWithSkippedStateStore.new(user: double(permitted?: false), providers: [1, 2])
        graph = GraphWithSkippedSteps.new(state_store:, current_step:).steps_processor

        expect(graph.next_step).to eq(:third_page)
        expect(graph.path_traversal(:fourth_page)).to eq(%i[first_page third_page fourth_page])
      end

      it 'skip second and third step when user not permitted and has single provider' do
        current_step = :first_page
        state_store =  GraphWithSkippedStateStore.new(user: double(permitted?: false), providers: [1])
        graph = GraphWithSkippedSteps.new(state_store:, current_step:).steps_processor

        expect(graph.next_step).to eq(:fourth_page)
        expect(graph.path_traversal(:fourth_page)).to eq(%i[first_page fourth_page])
      end
    end
  end

  describe '#previous_step' do
    it 'navigates back through path' do
      wizard.state_store.is_returning_user = false
      graph.path_traversal(:review)
      # Simulate wizard having traversed the path
      expect(graph.previous_step(:review)).to eq(:office_address)
    end

    it 'returns nil at root' do
      expect(graph.previous_step(:organization_type)).to be_nil
    end
  end

  describe '#path_traversal' do
    context 'new user - upper tier - listed activity' do
      before do
        wizard.state_store.is_returning_user = false
        wizard.state_store.waste_category = :upper_tier
        wizard.state_store.activity_type = :listed
      end

      it 'traverses correct path' do
        path = graph.path_traversal(:review)
        expect(path).to eq(%i[
                             organization_type
                             waste_category
                             activity_type
                             office_address
                             review
                           ])
      end
    end

    context 'returning user - lower tier' do
      before do
        wizard.state_store.is_returning_user = true
        wizard.state_store.waste_category = :lower_tier
      end

      it 'traverses correct path' do
        path = graph.path_traversal(:review)
        expect(path).to eq(%i[
                             account_login
                             waste_category
                             office_address
                             review
                           ])
      end
    end

    context 'unreachable step' do
      it 'returns empty array' do
        expect(graph.path_traversal(:nonexistent)).to eq([])
      end
    end
  end

  describe '#find_step' do
    it 'returns step class for existing node' do
      expect(graph.find_step(:organization_type)).to eq(Steps::OrganizationType)
    end

    it 'returns nil for missing node (never raises)' do
      expect(graph.find_step(:missing)).to be_nil
    end
  end

  describe '#step_definitions' do
    it 'returns all node IDs mapped to step classes' do
      definitions = graph.step_definitions
      expect(definitions).to include(
        organization_type: Steps::OrganizationType,
        waste_category: Steps::WasteCategory,
        activity_type: Steps::ActivityType,
        office_address: Steps::OfficeAddress,
        review: Steps::Review,
        issue_certificate: Steps::IssueCertificate,
      )
    end

    it 'includes all 9 steps' do
      expect(graph.step_definitions.size).to eq(10)
    end
  end

  describe '#metadata' do
    subject(:metadata) { graph.metadata }

    it 'has correct structure_type' do
      expect(metadata[:structure_type]).to eq(:graph)
    end

    it 'identifies multiple possible entry points' do
      possible_roots = metadata[:root_step]
      expect(possible_roots).to eq(%i[account_login organization_type])
    end

    it 'returns root when is only one' do
      root_step = PersonalInformationWizard.new(
        state_store: StateStores::PersonalInformation.new,
      ).steps_processor.metadata[:root_step]

      expect(root_step).to eq(:name_and_date_of_birth)
    end

    describe 'steps metadata' do
      it 'includes all steps with labels' do
        steps_meta = metadata[:steps]
        expect(steps_meta).to eq(
          {
            account_login: {
              class: 'Steps::AccountLogin',
              label: 'Account Login',
            },
            activity_type: {
              class: 'Steps::ActivityType',
              label: 'Activity Type',
            },
            waste_category: {
              class: 'Steps::WasteCategory',
              label: 'Waste Category',
            },
            issue_certificate: {
              class: 'Steps::IssueCertificate',
              label: 'Issue Certificate',
            },
            office_address: {
              class: 'Steps::OfficeAddress',
              label: 'Office Address',
            },
            organization_type: {
              class: 'Steps::OrganizationType',
              label: 'Organization Type',
            },
            pending_info: {
              class: 'Steps::PendingInfo',
              label: 'Pending Information',
            },
            rejection_notice: {
              class: 'Steps::RejectionNotice',
              label: 'Rejection Notice',
            },
            account_show: {
              class: 'DfE::Wizard::Core::Redirect',
              label: 'Account Show',
              skippable?: true,
              skip_when: :account_feature_flag_enabled?,
            },
            review: {
              class: 'Steps::Review',
              label: 'Review Application',
            },
          },
        )
      end
    end

    describe 'transitions metadata' do
      it 'includes all transitions' do
        expect(metadata[:transitions]).to eq(
          [
            { from: :organization_type, to: :waste_category, type: :simple, label: nil },
            { from: :account_login, to: :waste_category, type: :simple, label: nil },
            { from: :office_address, to: :review, type: :simple, label: nil },
            {
              from: :waste_category,
              when: :is_upper_tier_waste?,
              then: :activity_type,
              else: :office_address,
              type: :conditional,
              label: 'Upper tier waste?',
            },
            {
              from: :activity_type,
              branches: [
                { then: :office_address, label: 'Listed Activity', when: :is_listed_activity? },
                { then: :office_address, label: 'Non-listed Activity', when: :is_non_listed_activity? },
                { then: :review, label: 'Exempt Activity', when: :is_exempt_activity? },
              ],
              default: :office_address,
              type: :multiple_conditional,
              label: 'Activity Classification',
            },
            {
              from: :review,
              type: :custom_branching,
              potential_transitions: [
                { label: 'Submitted', nodes: [:review] },
                { label: 'Approved', nodes: [:issue_certificate] },
                { label: 'Rejected', nodes: [:rejection_notice] },
                { label: 'Pending', nodes: [:pending_info] },
              ],
            },
          ],
        )
      end
    end

    describe 'counts metadata' do
      it 'includes correct step count' do
        expect(metadata[:counts][:steps]).to eq(10)
      end

      it 'includes correct edge counts' do
        expect(metadata[:counts]).to include(
          simple_edges: 3,
          conditional_edges: 1,
          multiple_conditional_edges: 1,
          custom_branching_edges: 1,
        )
      end
    end

    it 'is serializable to JSON' do
      expect { JSON.generate(metadata) }.not_to raise_error
    end
  end

  describe 'Full wizard flow' do
    context 'new user - upper tier - exempt activity' do
      before do
        wizard.state_store.is_returning_user = false
        wizard.state_store.waste_category = :upper_tier
        wizard.state_store.activity_type = :exempt
        wizard.state_store.application_status = :approved
      end

      it 'navigates complete path' do
        current = graph.root_step
        path = [current]

        until current == :issue_certificate
          next_step = graph.next_step(current)
          break if next_step.nil?

          path << next_step
          current = next_step
        end

        expect(path).to eq(%i[
                             organization_type
                             waste_category
                             activity_type
                             review
                             issue_certificate
                           ])
      end
    end

    context 'returning user - lower tier' do
      before do
        wizard.state_store.is_returning_user = true
        wizard.state_store.waste_category = :lower_tier
        wizard.state_store.application_status = :rejected
      end

      it 'navigates correct path to rejection' do
        current = graph.root_step
        path = [current]

        until current == :rejection_notice
          next_step = graph.next_step(current)
          break if next_step.nil?

          path << next_step
          current = next_step
        end

        expect(path).to eq(%i[
                             account_login
                             waste_category
                             office_address
                             review
                             rejection_notice
                           ])
      end
    end
  end
end
