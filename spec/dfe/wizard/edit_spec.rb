RSpec.describe 'Edits of saved records' do
  include EditSpecHelpers

  before do
    EditSpecCommit.calls = []
    EditSpecCommit.result = { success: true }
  end

  describe 'start_edit' do
    it 'returns the first step of the unit' do
      expect(start_edit(:funding)).to eq(:funding)
    end

    it 'starts at the first step of a sub-wizard on the path, whatever step was named' do
      expect(start_edit(:deadline_at)).to eq(:student)
    end

    it 'seeds the answers on the record branch only' do
      start_edit(:funding)
      changeset = edit_request(:funding).changeset

      expect(changeset.seed).to eq(funding: 'fee', student_visa: false)
      expect(changeset.answers).to eq(funding: 'fee', student_visa: false)
    end

    it 'keeps updated_at, the record identity and the caller' do
      start_edit(:funding)
      changeset = edit_request(:funding).changeset

      expect(changeset.seed_updated_at).to eq('2026-10-09T12:00:00.123456Z')
      expect(changeset.caller_url).to eq('/records/1')
      expect(changeset).to be_edit
    end

    it 'starts a journey for the unit, with the seed as the snapshot' do
      start_edit(:funding)

      expect(edit_request(:funding).changeset.journey).to eq(
        unit: 'funding', shown: [], snapshot: { funding: 'fee', student_visa: false }, entry: 'funding',
      )
    end

    it 'raises without record:' do
      wizard = edit_request(nil, record: nil)

      expect { wizard.start_edit(unit: :funding, caller: '/') }.to raise_error(ArgumentError, /record:/)
    end

    it 'raises without a mapper' do
      wizard_class = Class.new(EditSpecWizard) { def mapper = nil }

      expect { edit_request(nil, wizard_class:).start_edit(unit: :funding, caller: '/') }
        .to raise_error(ArgumentError, /mapper/)
    end

    it 'raises without an on_commit operation' do
      wizard_class = Class.new(EditSpecWizard) do
        def steps_operator
          DfE::Wizard::StepsOperator::Builder.draw(wizard: self, callable: state_store) { |_builder| nil }
        end
      end

      expect { edit_request(nil, wizard_class:).start_edit(unit: :funding, caller: '/') }
        .to raise_error(ArgumentError, /on_commit/)
    end

    it 'raises for an unknown unit' do
      expect { start_edit(:nope) }.to raise_error(ArgumentError, /:nope is not a unit/)
    end

    it 'raises when the store already holds data, before writing' do
      start_edit(:funding)

      expect { start_edit(:funding) }.to raise_error(ArgumentError, /not empty/)
    end

    it 'raises NotCallable and discards the changeset when the unit has no step on the path' do
      wizard = edit_request(nil)
      allow(wizard).to receive(:full_path).and_return(%i[start funding start_date check_answers])

      expect { wizard.start_edit(unit: :visa, caller: '/') }.to raise_error(DfE::Wizard::NotCallable, /:visa/)
      expect(edit_repository.read).to eq({})
    end
  end

  describe 'mode checks' do
    it 'does not check in new' do
      expect { edit_request(:funding) }.not_to raise_error
    end

    it 'raises ChangesetExpired for a record: request over an empty changeset' do
      expect { edit_request(:funding).changeset }.to raise_error(DfE::Wizard::ChangesetExpired)
    end

    it 'raises ChangesetMismatch for another record' do
      start_edit(:funding)

      message = 'this changeset is an edit of EditSpecRecord/1, not EditSpecRecord/2'

      expect { edit_request(:funding, record: edit_record(id: 2)).changeset }
        .to raise_error(DfE::Wizard::ChangesetMismatch, message)
    end

    it 'raises ChangesetMismatch for a draft request over an edit changeset' do
      start_edit(:funding)

      expect { edit_request(:funding, record: nil).changeset }.to raise_error(DfE::Wizard::ChangesetMismatch)
    end

    it 'treats a wizard with its own record method, built without record:, as a draft' do
      wizard_class = Class.new(EditSpecWizard) { def record = EditSpecRecord.new(id: 9) }
      store = SubWizardSpecStore.new(repository: edit_repository)
      wizard = wizard_class.new(state_store: store, current_step: :funding,
                                current_step_params: { funding: { funding: 'fee' } })

      expect(wizard).not_to be_editing
      expect(wizard.save_current_step).to be_truthy
    end

    it 'checks once per wizard' do
      start_edit(:funding)
      wizard = edit_request(:funding)
      wizard.changeset
      allow(wizard.changeset).to receive(:check_mode!)
      wizard.changeset

      expect(wizard.changeset).not_to have_received(:check_mode!)
    end
  end

  describe 'navigation' do
    before { start_edit(:funding) }

    it 'goes Back to the caller URL from the first step' do
      wizard = edit_request(:funding)

      expect(wizard.previous_step).to be_nil
      expect(wizard.previous_step_path).to eq('/records/1')
    end

    it 'queues a dependent unit and goes Back to the unit before it' do
      wizard = submit_edit(:funding, funding: 'salary')

      expect(wizard.next_step).to eq(:skilled)
      expect(edit_request(:skilled).previous_step).to eq(:funding)
    end

    it 'ignores the start param' do
      expect(edit_request(:funding, { return_to_review: :start_date }).journey_start_redirect).to be_nil
    end
  end

  describe 'an edit opened on a step inside a sub-wizard' do
    let(:record) { edit_record(student_visa: true) }

    before { start_edit(:deadline_required, record:) }

    it 'opens on the step, and goes Back from it to the caller URL' do
      wizard = edit_request(:deadline_required, record:)

      expect(wizard.changeset.journey).to include(unit: 'visa', entry: 'deadline_required')
      expect(wizard.previous_step_path).to eq('/records/1')
    end

    it 'refuses a step of the unit before the entry step, and redirects to the entry step' do
      wizard = edit_request(:student, { student: { student_visa: true } }, record:)

      expect(wizard.step_accessible?(:student)).to be(false)
      expect(wizard.step_accessible?(:deadline_required)).to be(true)
      expect(wizard.redirect_step).to eq(:deadline_required)
      expect { wizard.save_current_step }.to raise_error(DfE::Wizard::StepNotAccessible, /:student/)
    end
  end

  describe 'the commit' do
    before { start_edit(:funding) }

    it 'commits the diff of answers on the path, then returns to the caller' do
      submit_edit(:funding, funding: 'salary')
      wizard = submit_edit(:skilled, skilled_visa: false)

      expect(EditSpecCommit.calls).to eq([{ funding: 'salary', skilled_visa: false }])
      expect(wizard.commit_result).to eq(status: :committed, errors: [])
      expect(wizard.next_step).to be_nil
      expect(wizard.next_step_path).to eq('/records/1')
    end

    it 'discards the changeset after the commit' do
      submit_edit(:funding, funding: 'salary')
      submit_edit(:skilled, skilled_visa: false)

      expect(edit_repository.read).to eq({})
    end

    it 'runs no operation when nothing changed' do
      wizard = submit_edit(:funding, funding: 'fee')

      expect(wizard.commit_result).to eq(status: :unchanged, errors: [])
      expect(EditSpecCommit.calls).to eq([])
      expect(edit_repository.read).to eq({})
    end

    it 'runs no operation when the record changed since the seed' do
      submit_edit(:funding, funding: 'salary')
      @request_record = edit_record(updated_at: EditSpecHelpers::SEEDED_AT + 1)
      wizard = submit_edit(:skilled, skilled_visa: false)

      expect(wizard.commit_result).to eq(status: :stale, errors: [])
      expect(EditSpecCommit.calls).to eq([])
      expect(edit_repository.read).to eq({})
    end

    it 'reports a failed operation with full messages' do
      errors = ActiveModel::Errors.new(edit_record)
      errors.add(:base, 'Funding cannot change')
      EditSpecCommit.result = { success: false, errors: }
      submit_edit(:funding, funding: 'salary')
      wizard = submit_edit(:skilled, skilled_visa: false)

      expect(wizard.commit_result).to eq(status: :failed, errors: ['Funding cannot change'])
      expect(wizard.next_step_path).to eq('/records/1')
      expect(edit_repository.read).to eq({})
    end

    it 'flattens errors given as a hash' do
      EditSpecCommit.result = { success: false, errors: { funding: ['is wrong'] } }
      submit_edit(:funding, funding: 'salary')

      expect(submit_edit(:skilled, skilled_visa: false).commit_result[:errors]).to eq(['is wrong'])
    end

    it 'keeps the changeset and the journey when an operation raises' do
      allow(EditSpecCommit).to receive(:new).and_raise('boom')
      submit_edit(:funding, funding: 'salary')

      expect { submit_edit(:skilled, skilled_visa: false) }.to raise_error('boom')
      expect(edit_request(:skilled).changeset.journey).to include(unit: 'visa')
    end

    it 'raises ChangesetExpired on a second submit of the last step' do
      submit_edit(:funding, funding: 'salary')
      submit_edit(:skilled, skilled_visa: false)

      expect { submit_edit(:skilled, skilled_visa: false) }.to raise_error(DfE::Wizard::ChangesetExpired)
    end
  end

  describe 'step access' do
    before { start_edit(:funding) }

    it 'allows the steps of the current unit' do
      expect(edit_request(:funding).step_accessible?(:funding)).to be(true)
    end

    it 'refuses other steps and the check answers node' do
      wizard = edit_request(:funding)

      expect(wizard.step_accessible?(:start_date)).to be(false)
      expect(wizard.step_accessible?(:student)).to be(false)
      expect(wizard.step_accessible?(:check_answers)).to be(false)
    end

    it 'allows a shown unit and the queued unit after chaining' do
      submit_edit(:funding, funding: 'salary')
      wizard = edit_request(:skilled)

      expect(wizard.step_accessible?(:funding)).to be(true)
      expect(wizard.step_accessible?(:skilled)).to be(true)
      expect(wizard.step_accessible?(:student)).to be(false)
    end

    it 'redirects to the first step of the current unit' do
      expect(edit_request(:start_date).redirect_step).to eq(:funding)
    end

    it 'raises StepNotAccessible on save, before any operation' do
      wizard = edit_request(:start_date, { start_date: {} })

      expect { wizard.save_current_step }.to raise_error(DfE::Wizard::StepNotAccessible, /:start_date/)
      expect(edit_request(:funding).changeset.journey).to include(unit: 'funding')
    end

    it 'allows every step on a draft' do
      draft = journey_request_for_draft(:start_date)

      expect(draft.step_accessible?(:check_answers)).to be(true)
    end

    def journey_request_for_draft(step)
      EditSpecWizard.new(state_store: SubWizardSpecStore.new(repository: DfE::Wizard::Repository::InMemory.new),
                         current_step: step)
    end
  end

  describe 'answers_on_path' do
    it 'drops answers for steps that left the path' do
      start_edit(:funding)
      submit_edit(:funding, funding: 'salary')

      expect(edit_request(:skilled).answers_on_path).to eq(funding: 'salary')
    end
  end
end
