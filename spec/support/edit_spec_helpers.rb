require_relative 'journey_spec_helpers'

# A saved record for edit specs.
EditSpecRecord = Struct.new(:id, :funding, :student_visa, :skilled_visa, :updated_at, keyword_init: true)

# Seeds only the answers on the record's own branch.
class EditSpecMapper
  include DfE::Wizard::Mapper

  def to_answers(record)
    visa = record.funding == 'salary' ? { skilled_visa: record.skilled_visa } : { student_visa: record.student_visa }
    { funding: record.funding }.merge(visa)
  end
end

# A commit operation that records what it saw and returns a set result.
class EditSpecCommit
  class << self
    attr_accessor :calls, :result
  end

  def initialize(repository:, step:)
    @repository = repository
    @step = step
  end

  def execute
    self.class.calls << @step.wizard.changeset.diff
    self.class.result
  end
end

# The change journey spec wizard, with a mapper and a commit.
class EditSpecWizard < JourneySpecWizard
  def mapper
    EditSpecMapper.new
  end

  def steps_operator
    DfE::Wizard::StepsOperator::Builder.draw(wizard: self, callable: state_store) do |builder|
      builder.on_commit(use: [EditSpecCommit])
    end
  end
end

module EditSpecHelpers
  CALLER_URL = '/records/1'.freeze
  SEEDED_AT = Time.utc(2026, 10, 9, 12, 0, 0, 123_456)

  def edit_record(**changes)
    EditSpecRecord.new(id: 1, funding: 'fee', student_visa: false, skilled_visa: nil, updated_at: SEEDED_AT, **changes)
  end

  def edit_repository
    @edit_repository ||= DfE::Wizard::Repository::InMemory.new
  end

  # One request of an edit, as a controller builds it.
  def edit_request(step, params = {}, record: edit_record, wizard_class: EditSpecWizard)
    store = SubWizardSpecStore.new(repository: edit_repository)
    wizard_class.new(state_store: store, current_step: step, current_step_params: params, record:)
  end

  # The entry point. Returns the first step.
  def start_edit(unit, record: edit_record)
    edit_request(nil, record:).start_edit(unit:, caller: CALLER_URL)
  end

  # PATCH a step in the edit, with the record a request loads (set
  # @request_record to change it). Returns the wizard, to read
  # next_step_path and commit_result.
  def submit_edit(step, answers = {})
    edit_request(step, { step => answers }, record: @request_record || edit_record).tap do |wizard|
      raise "save failed on #{step}" unless wizard.save_current_step
    end
  end
end
