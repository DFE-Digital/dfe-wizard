RSpec.describe DfE::Wizard::Documentation::Formatters::MarkdownFormatter do
  def load_metadata_fixture(filename)
    fixture_path = File.join('spec', 'fixtures', 'documentation', 'formatters', 'metadata', filename)
    JSON.parse(File.read(File.expand_path(fixture_path)), symbolize_names: true)
  rescue Errno::ENOENT
    raise "Metadata fixture not found: #{fixture_path}"
  end

  def load_expected_markdown(scenario_name)
    fixture_path = File.join('spec', 'fixtures', 'documentation', 'formatters', 'markdown', "#{scenario_name}.md")
    File.read(File.expand_path(fixture_path))
  rescue Errno::ENOENT
    raise "Expected markdown fixture not found: #{fixture_path}"
  end

  def normalize_whitespace(str)
    str.strip.gsub("\r\n", "\n")
  end

  describe 'minimal two-step wizard' do
    let(:metadata) do
      {
        structure_type: :graph,
        root_step: :start,
        steps: {
          start: { label: 'Start', class: 'Steps::Start', attributes: [], validators: [], operations: [] },
          end: { label: 'End', class: 'Steps::End', attributes: [], validators: [], operations: [] },
        },
        transitions: [{ type: :simple, from: :start, to: :end }],
        counts: {
          steps: 2,
          simple_transitions: 1,
          conditional_transitions: 0,
          multiple_conditional_transitions: 0,
          custom_branching_transitions: 0,
        },
      }
    end

    it 'matches minimal_metadata.md fixture' do
      formatter = described_class.new(metadata)
      result = formatter.render
      expected = load_expected_markdown('minimal_metadata')

      expect(normalize_whitespace(result)).to eq(normalize_whitespace(expected))
    end
  end

  describe 'linear three-step wizard' do
    let(:metadata) do
      load_metadata_fixture('metadata_linear.json')
    end

    it 'matches linear_metadata.md fixture' do
      formatter = described_class.new(metadata)
      result = formatter.render
      expected = load_expected_markdown('linear_metadata')

      expect(normalize_whitespace(result)).to eq(normalize_whitespace(expected))
    end
  end

  describe 'complex graph wizard (DEFRA waste exemption)' do
    let(:metadata) do
      load_metadata_fixture('metadata_graph.json')
    end

    it 'matches graph_metadata.md fixture' do
      formatter = described_class.new(metadata)
      result = formatter.render
      expected = load_expected_markdown('graph_metadata')

      expect(normalize_whitespace(result)).to eq(normalize_whitespace(expected))
    end
  end

  describe 'dynamic root entry points' do
    let(:metadata) do
      {
        structure_type: :graph,
        root_step: %i[login register],
        steps: {
          login: { label: 'Login', class: 'Steps::Login', attributes: [], validators: [], operations: [] },
          register: { label: 'Register', class: 'Steps::Register', attributes: [], validators: [], operations: [] },
          dashboard: { label: 'Dashboard', class: 'Steps::Dashboard', attributes: [], validators: [], operations: [] },
        },
        transitions: [
          { type: :simple, from: :login, to: :dashboard },
          { type: :simple, from: :register, to: :dashboard },
        ],
        counts: { steps: 3, simple_transitions: 2, conditional_transitions: 0, multiple_conditional_transitions: 0,
                  custom_branching_transitions: 0 },
      }
    end

    it 'matches dynamic_root.md fixture' do
      formatter = described_class.new(metadata)
      result = formatter.render
      expected = load_expected_markdown('dynamic_root')

      expect(normalize_whitespace(result)).to eq(normalize_whitespace(expected))
    end
  end

  describe 'rich step data (attributes, validators, operations)' do
    let(:metadata) do
      {
        structure_type: :graph,
        root_step: :personal_info,
        steps: {
          personal_info: {
            label: 'Personal Information',
            class: 'Steps::PersonalInfo',
            attributes: [
              { name: 'first_name', type: 'String', required: true, description: 'First name of applicant' },
              { name: 'last_name', type: 'String', required: true, description: 'Last name of applicant' },
              { name: 'date_of_birth', type: 'Date', required: true, description: 'Date of birth (YYYY-MM-DD)' },
              { name: 'email', type: 'String', required: true, description: 'Valid email address' },
            ],
            validators: [
              { name: 'first_name', type: 'presence', message: 'cannot be blank',
                code: 'validates :first_name, presence: true' },
              { name: 'email', type: 'format', message: 'must be valid email',
                code: 'validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }' },
              { name: 'date_of_birth', type: 'comparison', message: 'must be in past',
                code: 'validates :date_of_birth, comparison: { less_than: Date.today }' },
            ],
            operations: [
              { name: 'strip_whitespace', hook: :before_save, description: 'Remove leading/trailing spaces',
                code: 'before_save :strip_whitespace' },
              { name: 'send_confirmation_email', hook: :after_save, description: 'Send email confirmation',
                code: 'after_save :send_confirmation_email' },
            ],
          },
          review: { label: 'Review', class: 'Steps::Review', attributes: [], validators: [], operations: [] },
        },
        transitions: [{ type: :simple, from: :personal_info, to: :review }],
        counts: { steps: 2, simple_transitions: 1, conditional_transitions: 0, multiple_conditional_transitions: 0,
                  custom_branching_transitions: 0 },
      }
    end

    it 'matches rich_step.md fixture' do
      formatter = described_class.new(metadata)
      result = formatter.render
      expected = load_expected_markdown('rich_step')

      expect(normalize_whitespace(result)).to eq(normalize_whitespace(expected))
    end
  end

  describe 'conditional if/else branching' do
    let(:metadata) do
      {
        structure_type: :graph,
        root_step: :age_check,
        steps: {
          age_check: { label: 'Age Check', class: 'Steps::AgeCheck', attributes: [], validators: [], operations: [] },
          adult_form: { label: 'Adult Form', class: 'Steps::AdultForm', attributes: [], validators: [],
                        operations: [] },
          minor_form: { label: 'Minor Form', class: 'Steps::MinorForm', attributes: [], validators: [],
                        operations: [] },
          summary: { label: 'Summary', class: 'Steps::Summary', attributes: [], validators: [], operations: [] },
        },
        transitions: [
          { type: :conditional, from: :age_check, then: :adult_form, else: :minor_form, label: 'Is adult (18+)?' },
          { type: :simple, from: :adult_form, to: :summary },
          { type: :simple, from: :minor_form, to: :summary },
        ],
        counts: { steps: 4, simple_transitions: 2, conditional_transitions: 1, multiple_conditional_transitions: 0,
                  custom_branching_transitions: 0 },
      }
    end

    it 'matches conditional.md fixture' do
      formatter = described_class.new(metadata)
      result = formatter.render
      expected = load_expected_markdown('conditional')

      expect(normalize_whitespace(result)).to eq(normalize_whitespace(expected))
    end
  end

  describe 'multiple conditional N-way branching' do
    let(:metadata) do
      {
        structure_type: :graph,
        root_step: :user_type,
        steps: {
          user_type: { label: 'User Type', class: 'Steps::UserType', attributes: [], validators: [], operations: [] },
          admin_panel: { label: 'Admin Panel', class: 'Steps::AdminPanel', attributes: [], validators: [],
                         operations: [] },
          moderator_panel: { label: 'Moderator Panel', class: 'Steps::ModeratorPanel', attributes: [], validators: [],
                             operations: [] },
          user_dashboard: { label: 'User Dashboard', class: 'Steps::UserDashboard', attributes: [], validators: [],
                            operations: [] },
          guest_view: { label: 'Guest View', class: 'Steps::GuestView', attributes: [], validators: [],
                        operations: [] },
        },
        transitions: [
          {
            type: :multiple_conditional,
            from: :user_type,
            branches: [
              { label: 'Admin User', then: :admin_panel },
              { label: 'Moderator User', then: :moderator_panel },
              { label: 'Regular User', then: :user_dashboard },
            ],
            default: :guest_view,
            label: 'User Role Classification',
          },
        ],
        counts: { steps: 5, simple_transitions: 0, conditional_transitions: 0, multiple_conditional_transitions: 1,
                  custom_branching_transitions: 0 },
      }
    end

    it 'matches multiple_conditional.md fixture' do
      formatter = described_class.new(metadata)
      result = formatter.render
      expected = load_expected_markdown('multiple_conditional')

      expect(normalize_whitespace(result)).to eq(normalize_whitespace(expected))
    end
  end

  describe 'custom branching status-driven routing' do
    let(:metadata) do
      {
        structure_type: :graph,
        root_step: :application_status,
        steps: {
          application_status: { label: 'Application Status', class: 'Steps::ApplicationStatus', attributes: [],
                                validators: [], operations: [] },
          pending: { label: 'Pending Review', class: 'Steps::Pending', attributes: [], validators: [], operations: [] },
          approved: { label: 'Approved', class: 'Steps::Approved', attributes: [], validators: [], operations: [] },
          rejected: { label: 'Rejected', class: 'Steps::Rejected', attributes: [], validators: [], operations: [] },
          revision: { label: 'Request Revision', class: 'Steps::Revision', attributes: [], validators: [],
                      operations: [] },
        },
        transitions: [
          {
            type: :custom_branching,
            from: :application_status,
            conditional: :determine_status_path,
            potential_transitions: [
              { label: 'Under Review', nodes: [:pending] },
              { label: 'Approved', nodes: [:approved] },
              { label: 'Rejected', nodes: [:rejected] },
              { label: 'Needs Revision', nodes: [:revision] },
            ],
          },
        ],
        counts: { steps: 5, simple_transitions: 0, conditional_transitions: 0, multiple_conditional_transitions: 0,
                  custom_branching_transitions: 1 },
      }
    end

    it 'matches custom_branching.md fixture' do
      formatter = described_class.new(metadata)
      result = formatter.render
      expected = load_expected_markdown('custom_branching')

      expect(normalize_whitespace(result)).to eq(normalize_whitespace(expected))
    end
  end

  describe 'single step wizard (edge case)' do
    let(:metadata) do
      {
        structure_type: :graph,
        root_step: :only_step,
        steps: {
          only_step: { label: 'Only Step', class: 'Steps::OnlyStep', attributes: [], validators: [], operations: [] },
        },
        transitions: [],
        counts: { steps: 1, simple_transitions: 0, conditional_transitions: 0, multiple_conditional_transitions: 0,
                  custom_branching_transitions: 0 },
      }
    end

    it 'matches single_step.md fixture' do
      formatter = described_class.new(metadata)
      result = formatter.render
      expected = load_expected_markdown('single_step')

      expect(normalize_whitespace(result)).to eq(normalize_whitespace(expected))
    end
  end

  describe 'empty wizard (edge case)' do
    let(:metadata) do
      {
        structure_type: :graph,
        root_step: nil,
        steps: {},
        transitions: [],
        counts: { steps: 0, simple_transitions: 0, conditional_transitions: 0, multiple_conditional_transitions: 0,
                  custom_branching_transactions: 0 },
      }
    end

    it 'matches empty_wizard.md fixture' do
      formatter = described_class.new(metadata)
      result = formatter.render
      expected = load_expected_markdown('empty_wizard')

      expect(normalize_whitespace(result)).to eq(normalize_whitespace(expected))
    end
  end

  describe 'graph wizard with step_attributes disabled' do
    let(:metadata) do
      load_metadata_fixture('metadata_graph.json')
    end

    it 'matches graph_metadata_no_attributes.md fixture' do
      formatter = described_class.new(metadata, step_attributes: false)
      result = formatter.render
      expected = load_expected_markdown('graph_metadata_no_attributes')

      expect(normalize_whitespace(result)).to eq(normalize_whitespace(expected))
    end
  end

  describe 'graph wizard with step_validations disabled' do
    let(:metadata) do
      load_metadata_fixture('metadata_graph.json')
    end

    it 'matches graph_metadata_no_validations.md fixture' do
      formatter = described_class.new(metadata, step_validations: false)
      result = formatter.render
      expected = load_expected_markdown('graph_metadata_no_validations')

      expect(normalize_whitespace(result)).to eq(normalize_whitespace(expected))
    end
  end

  describe 'graph wizard with step_operations disabled' do
    let(:metadata) do
      load_metadata_fixture('metadata_graph.json')
    end

    it 'matches graph_metadata_no_operations.md fixture' do
      formatter = described_class.new(metadata, step_operations: false)
      result = formatter.render
      expected = load_expected_markdown('graph_metadata_no_operations')

      expect(normalize_whitespace(result)).to eq(normalize_whitespace(expected))
    end
  end

  describe 'graph wizard with include_raw_metadata disabled' do
    let(:metadata) do
      load_metadata_fixture('metadata_graph.json')
    end

    it 'matches graph_metadata_no_raw_metadata.md fixture' do
      formatter = described_class.new(metadata, include_raw_metadata: false)
      result = formatter.render
      expected = load_expected_markdown('graph_metadata_no_raw_metadata')

      expect(normalize_whitespace(result)).to eq(normalize_whitespace(expected))
    end
  end
end
