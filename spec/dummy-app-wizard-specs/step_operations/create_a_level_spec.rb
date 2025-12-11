RSpec.describe StepOperations::CreateALevel do
  subject(:operation) do
    described_class.new(
      repository: DfE::Wizard::Repository::Model.new(record: course),
      step:,
    )
  end

  let(:step) do
    Steps::WhatALevelIsRequired.new(step_params)
  end

  let(:course) { create(:course) }

  describe '#execute' do
    subject { operation.execute }

    before do
      allow(SecureRandom).to receive(:uuid).and_return('generated-uuid')
    end

    context 'when creating a new A level other subject requirement' do
      let(:step_params) do
        {
          subject: 'other_subject',
          other_subject: 'Mathematics',
          minimum_grade_required: 'D',
        }
      end

      it 'adds the requirement to the course' do
        expect { subject }.to change { course.reload.a_level_subject_requirements.count }.by(1)

        expect(course.a_level_subject_requirements).to eq(
          [
            {
              'uuid' => 'generated-uuid',
              'subject' => 'other_subject',
              'other_subject' => 'Mathematics',
              'minimum_grade_required' => 'D',
            },
          ],
        )
      end

      it 'returns true' do
        expect(subject).to eq(success: true)
      end
    end

    context 'when creating an A level any subject requirement' do
      let(:step_params) do
        {
          subject: 'any_subject',
          minimum_grade_required: 'D',
        }
      end

      it 'adds the requirement without other_subject key' do
        expect { subject }.to change { course.reload.a_level_subject_requirements.count }.by(1)

        expect(course.a_level_subject_requirements).to eq(
          [
            {
              'uuid' => 'generated-uuid',
              'subject' => 'any_subject',
              'minimum_grade_required' => 'D',
            },
          ],
        )
      end
    end

    context 'when creating without minimum grade' do
      let(:step_params) do
        {
          subject: 'other_subject',
          other_subject: 'Mathematics',
        }
      end

      it 'omits minimum_grade_required key' do
        expect { subject }.to change { course.reload.a_level_subject_requirements.count }.by(1)

        expect(course.a_level_subject_requirements).to eq(
          [
            {
              'uuid' => 'generated-uuid',
              'subject' => 'other_subject',
              'other_subject' => 'Mathematics',
            },
          ],
        )
      end
    end

    context 'when updating an existing requirement' do
      let(:course) { create(:course, :with_a_level_requirements) }
      let(:existing_uuid) { course.a_level_subject_requirements.first['uuid'] }

      let(:step_params) do
        {
          uuid: existing_uuid,
          subject: 'any_stem_subject',
          minimum_grade_required: 'B',
        }
      end

      it 'updates the existing requirement' do
        expect { subject }.not_to(change { course.reload.a_level_subject_requirements.count })

        updated = course.a_level_subject_requirements.find { |r| r['uuid'] == existing_uuid }
        expect(updated['subject']).to eq('any_stem_subject')
        expect(updated['minimum_grade_required']).to eq('B')
      end
    end

    context 'when converting from other_subject to any_subject' do
      let(:course) do
        create(
          :course,
          a_level_subject_requirements: [
            { uuid: 'test-uuid', subject: 'other_subject', other_subject: 'Mathematics' },
          ],
        )
      end

      let(:step_params) do
        {
          uuid: 'test-uuid',
          subject: 'any_subject',
          minimum_grade_required: 'D',
        }
      end

      it 'removes other_subject and keeps other fields' do
        subject
        course.reload

        updated = course.a_level_subject_requirements.find { |r| r['uuid'] == 'test-uuid' }
        expect(updated['subject']).to eq('any_subject')
        expect(updated).not_to have_key('other_subject')
        expect(updated['minimum_grade_required']).to eq('D')
      end
    end

    context 'when step validation fails' do
      let(:step_params) { {} }

      it 'returns false without saving' do
        expect { subject }.not_to(change { course.reload.a_level_subject_requirements })
        expect(subject).to eq(success: false, errors: step.errors)
      end
    end
  end
end
