RSpec.describe StepOperations::RemoveALevelSubjectConfirmation do
  subject(:operation) do
    described_class.new(
      repository: DfE::Wizard::Repository::Model.new(record: course),
      step:,
    )
  end

  let(:step) do
    Steps::RemoveALevelSubjectConfirmation.new(step_params)
  end

  let(:course) { create(:course, :with_a_level_requirements, a_level_subject_requirements:) }
  let(:a_level_subject_requirements) do
    [
      { 'uuid' => 'the-uuid-1', 'subject' => 'any_subject', 'minimum_grade_required' => 'B' },
      { 'uuid' => 'the-uuid-2', 'subject' => 'other_subject', 'other_subject' => 'Mathematics',
        'minimum_grade_required' => 'A' },
    ]
  end
  let(:step_params) do
    { uuid: 'the-uuid-1', confirmation: }
  end
  let(:confirmation) { nil }

  describe '#execute' do
    context 'when step is invalid' do
      let(:step_params) { {} }

      it 'returns failed operation' do
        expect(operation.execute).to eq(success: false, errors: step.errors)
      end
    end

    context 'when confirmation is yes' do
      let(:confirmation) { 'yes' }

      it 'removes the hash with the given uuid from a_level_subject_requirements and updates the course' do
        expect(course.a_level_subject_requirements.size).to eq(2)
        expect(course.a_level_subject_requirements.any? { |req| req['uuid'] == 'the-uuid-1' }).to be true

        operation.execute

        expect(course.reload.a_level_subject_requirements.size).to eq(1)
        expect(course.a_level_subject_requirements.any? { |req| req['uuid'] == 'the-uuid-1' }).to be false
      end
    end

    context 'when removing the last A level subject requirement' do
      let(:confirmation) { 'yes' }
      let(:a_level_subject_requirements) do
        [
          { 'uuid' => 'the-uuid-1', 'subject' => 'any_subject', 'minimum_grade_required' => 'B' },
        ]
      end

      it 'sets specific fields to nil if a_level_subject_requirements becomes empty' do
        expect(course.reload.a_level_subject_requirements).to eq(a_level_subject_requirements)

        operation.execute

        expect(course.reload.a_level_subject_requirements).to be_empty
        expect(course.accept_pending_a_level).to be_nil
        expect(course.accept_a_level_equivalency).to be_nil
        expect(course.additional_a_level_equivalencies).to be_nil
      end
    end

    context 'when confirmation is not yes' do
      let(:confirmation) { 'no' }

      it 'does not remove any hash and does not alter the a_level_subject_requirements' do
        expect(operation.execute).to eq(success: false)

        expect(course.reload.a_level_subject_requirements.size).to eq(2)
      end
    end
  end
end
