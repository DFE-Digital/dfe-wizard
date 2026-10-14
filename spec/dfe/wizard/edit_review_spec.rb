RSpec.describe 'The edit review' do
  include EditSpecHelpers

  def edit_wizard_class
    EditReviewSpecWizard
  end

  def edit_record(**changes)
    super(published: true, **changes)
  end

  before do
    EditSpecCommit.calls = []
    EditSpecCommit.result = { success: true }
    start_edit(:funding)
  end

  describe 'an edit with a change' do
    it 'goes to the edit review instead of committing' do
      submit_edit(:funding, funding: 'salary')
      wizard = submit_edit(:skilled, skilled_visa: false)

      expect(wizard.next_step).to eq(:confirm)
      expect(wizard.next_step_path).to eq('/journey/confirm')
      expect(wizard.commit_result).to be_nil
      expect(EditSpecCommit.calls).to eq([])
      expect(edit_request(:confirm).changeset.journey).to include(review: true)
    end

    it 'commits when the edit review is saved, then returns to the caller' do
      submit_edit(:funding, funding: 'salary')
      submit_edit(:skilled, skilled_visa: false)
      wizard = submit_edit(:confirm)

      expect(EditSpecCommit.calls).to eq([{ funding: 'salary', skilled_visa: false }])
      expect(wizard.commit_result).to eq(status: :committed, errors: [])
      expect(wizard.next_step_path).to eq('/records/1')
      expect(edit_repository.read).to eq({})
    end

    it 'checks the record is not stale when the edit review is saved' do
      submit_edit(:funding, funding: 'salary')
      submit_edit(:skilled, skilled_visa: false)
      @request_record = edit_record(updated_at: EditSpecHelpers::SEEDED_AT + 1)

      expect(submit_edit(:confirm).commit_result).to eq(status: :stale, errors: [])
      expect(EditSpecCommit.calls).to eq([])
    end

    it 'raises ChangesetExpired on a second submit of the edit review' do
      submit_edit(:funding, funding: 'salary')
      submit_edit(:skilled, skilled_visa: false)
      submit_edit(:confirm)

      expect { submit_edit(:confirm) }.to raise_error(DfE::Wizard::ChangesetExpired)
    end
  end

  describe 'Back' do
    before do
      submit_edit(:funding, funding: 'salary')
      submit_edit(:skilled, skilled_visa: false)
    end

    it 'goes from the edit review to the last step shown' do
      wizard = edit_request(:confirm)

      expect(wizard.previous_step).to eq(:skilled)
      expect(wizard.previous_step_path).to eq('/journey/skilled')
    end

    it 'goes from the first step of the last unit to the unit shown before it' do
      wizard = edit_request(:skilled)

      expect(wizard.previous_step).to eq(:funding)
      expect(wizard.previous_step_path).to eq('/journey/funding')
    end

    it 'returns to the edit review when the last step is saved again' do
      expect(submit_edit(:skilled, skilled_visa: false).next_step).to eq(:confirm)
      expect(EditSpecCommit.calls).to eq([])
    end

    it 'commits with no review when an earlier answer is changed back' do
      wizard = submit_edit(:funding, funding: 'fee')

      expect(wizard.commit_result).to eq(status: :unchanged, errors: [])
      expect(wizard.next_step_path).to eq('/records/1')
    end
  end

  describe 'step access' do
    it 'refuses the edit review before the journey ends' do
      expect(edit_request(:funding).step_accessible?(:confirm)).to be(false)
      expect { edit_request(:confirm, { confirm: {} }).save_current_step }
        .to raise_error(DfE::Wizard::StepNotAccessible)
    end

    it 'allows the edit review and the steps shown while the edit waits on it' do
      submit_edit(:funding, funding: 'salary')
      submit_edit(:skilled, skilled_visa: false)
      wizard = edit_request(:confirm)

      expect(wizard.step_accessible?(:confirm)).to be(true)
      expect(wizard.step_accessible?(:funding)).to be(true)
      expect(wizard.step_accessible?(:skilled)).to be(true)
      expect(wizard.step_accessible?(:start_date)).to be(false)
    end

    it 'redirects to the edit review while the edit waits on it' do
      submit_edit(:funding, funding: 'salary')
      submit_edit(:skilled, skilled_visa: false)

      expect(edit_request(:start_date).redirect_step).to eq(:confirm)
    end
  end

  describe 'no edit review' do
    it 'commits directly when its skip_when holds' do
      @request_record = edit_record(published: false)
      submit_edit(:funding, funding: 'salary')
      wizard = submit_edit(:skilled, skilled_visa: false)

      expect(wizard.commit_result).to eq(status: :committed, errors: [])
      expect(wizard.next_step_path).to eq('/records/1')
    end

    it 'commits directly when nothing changed' do
      wizard = submit_edit(:funding, funding: 'fee')

      expect(wizard.commit_result).to eq(status: :unchanged, errors: [])
      expect(wizard.next_step_path).to eq('/records/1')
    end

    it 'never shows on a draft' do
      store = SubWizardSpecStore.new(repository: DfE::Wizard::Repository::InMemory.new)
      store.write(funding: 'fee', student_visa: false)
      draft = lambda do |step, params = {}|
        EditReviewSpecWizard.new(state_store: store, current_step: step, current_step_params: params)
      end
      draft.call(:funding, { return_to_review: :funding }).journey_start_redirect
      draft.call(:funding, { funding: { funding: 'salary' } }).save_current_step
      wizard = draft.call(:skilled, { skilled: { skilled_visa: false } })
      wizard.save_current_step

      expect(wizard.next_step).to eq(:check_answers)
    end
  end

  describe 'changeset.edit_unit' do
    it 'is the unit the edit started with, whatever units it showed' do
      submit_edit(:funding, funding: 'salary')

      expect(edit_request(:skilled).changeset.edit_unit).to eq(:funding)
    end
  end
end
