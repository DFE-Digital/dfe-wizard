RSpec.describe ALevelsRequirementsWizard do
  let(:course) do
    create(
      :course,
      course_code: 'ABC123',
      provider_code: 'XYZ',
      recruitment_cycle_year: 2025,
    )
  end

  let(:repository) { Repositories::ALevelsRequirements.new(record: course) }
  let(:state_store) { StateStores::ALevelsRequirements.new(repository:) }
  let(:current_step_params) { {} }
  let(:url_helpers) { Rails.application.routes.url_helpers }
  let(:current_step) { :add_a_level_to_a_list }

  subject(:wizard) do
    described_class.new(
      state_store:,
      current_step:,
      current_step_params:,
    )
  end

  before { skip }

  describe 'root step determination' do
    context 'when no A-levels exist' do
      it 'has what_a_level_is_required as root step' do
        course.update!(a_level_subject_requirements: [])
        expect(wizard).to have_root_step(:what_a_level_is_required)
      end
    end

    context 'when A-levels already exist' do
      it 'has add_a_level_to_a_list as root step' do
        expect(wizard).to have_root_step(:add_a_level_to_a_list).when(
          a_level_subject_requirements: [
            { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
          ],
        )
      end
    end

    context 'when multiple A-levels exist' do
      it 'has add_a_level_to_a_list as root step' do
        expect(wizard).to have_root_step(:add_a_level_to_a_list).when(
          a_level_subject_requirements: [
            { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
            { uuid: '456', subject: 'physics', minimum_grade_required: 'B' },
          ],
        )
      end
    end

    context 'when maximum A-levels exist (4)' do
      it 'has add_a_level_to_a_list as root step' do
        expect(wizard).to have_root_step(:add_a_level_to_a_list).when(
          a_level_subject_requirements: [
            { uuid: '1', subject: 'maths', minimum_grade_required: 'A' },
            { uuid: '2', subject: 'physics', minimum_grade_required: 'B' },
            { uuid: '3', subject: 'chemistry', minimum_grade_required: 'A' },
            { uuid: '4', subject: 'biology', minimum_grade_required: 'B' },
          ],
        )
      end
    end
  end

  describe 'flow path traversal' do
    context 'when no A-levels added yet' do
      context 'at what_a_level_is_required step' do
        let(:current_step) { :what_a_level_is_required }

        before do
          state_store.write(a_level_subject_requirements: [])
        end

        it { is_expected.to be_at_step(:what_a_level_is_required) }

        it 'returns flow path' do
          expect(wizard).to have_flow_path([:what_a_level_is_required])
        end
      end
    end

    context 'when one A-level added and adding another' do
      before do
        state_store.write(
          a_level_subject_requirements: [
            { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
          ],
          add_another_a_level: 'yes',
        )
      end

      context 'at add_a_level_to_a_list step' do
        let(:current_step) { :add_a_level_to_a_list }
        let(:current_step_params) { { add_another_a_level: 'yes' } }

        it { is_expected.to be_at_step(:add_a_level_to_a_list) }

        it 'branches back to what_a_level_is_required when adding another' do
          wizard.save
          expect(wizard).to branch_from(:add_a_level_to_a_list).to(:what_a_level_is_required)
        end
      end
    end

    context 'when 4 A-levels added (maximum reached)' do
      before do
        state_store.write(
          a_level_subject_requirements: [
            { uuid: '1', subject: 'maths', minimum_grade_required: 'A' },
            { uuid: '2', subject: 'physics', minimum_grade_required: 'B' },
            { uuid: '3', subject: 'chemistry', minimum_grade_required: 'A' },
            { uuid: '4', subject: 'biology', minimum_grade_required: 'B' },
          ],
        )
      end

      context 'at add_a_level_to_a_list step' do
        let(:current_step) { :add_a_level_to_a_list }

        it 'automatically proceeds to consider_pending_a_level' do
          expect(wizard).to have_next_step(:consider_pending_a_level)
        end

        it 'branches to consider_pending_a_level without user choice' do
          expect(wizard).to branch_from(:add_a_level_to_a_list).to(:consider_pending_a_level)
        end
      end
    end

    context 'when A-levels complete and not adding more' do
      before do
        state_store.write(
          a_level_subject_requirements: [
            { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
            { uuid: '456', subject: 'physics', minimum_grade_required: 'B' },
          ],
          add_another_a_level: 'no',
        )
      end

      context 'at add_a_level_to_a_list step' do
        let(:current_step) { :add_a_level_to_a_list }
        let(:current_step_params) { { add_another_a_level: 'no' } }

        it { is_expected.to be_at_step(:add_a_level_to_a_list) }

        it 'branches to consider_pending_a_level when done adding' do
          expect(wizard).to branch_from(:add_a_level_to_a_list).to(:consider_pending_a_level)
        end
      end

      context 'at consider_pending_a_level step' do
        let(:current_step) { :consider_pending_a_level }

        before do
          state_store.write(
            a_level_subject_requirements: [
              { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
            ],
            pending_a_level: 'yes',
          )
        end

        it { is_expected.to be_at_step(:consider_pending_a_level) }

        it 'proceeds to a_level_equivalencies' do
          expect(wizard).to have_next_step(:a_level_equivalencies)
        end
      end

      context 'at a_level_equivalencies step' do
        let(:current_step) { :a_level_equivalencies }

        before do
          state_store.write(
            a_level_subject_requirements: [
              { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
            ],
            pending_a_level: 'yes',
            accept_a_level_equivalency: 'yes',
            additional_a_level_equivalencies: 'IB Diploma accepted',
          )
        end

        it { is_expected.to be_at_step(:a_level_equivalencies) }

        it 'proceeds to course_edit redirect' do
          expect(wizard).to have_next_step(:course_edit)
        end

        it 'branches to course_edit' do
          expect(wizard).to branch_from(:a_level_equivalencies).to(:course_edit)
        end

        it 'flow path includes full journey' do
          expect(wizard).to have_flow_path(
            %i[
              what_a_level_is_required
              add_a_level_to_a_list
              consider_pending_a_level
              a_level_equivalencies
              course_edit
            ],
          )
        end
      end
    end

    context 'when removing an A-level' do
      before do
        state_store.write(
          a_level_subject_requirements: [
            { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
            { uuid: '456', subject: 'physics', minimum_grade_required: 'B' },
          ],
        )
      end

      context 'at remove_a_level_subject_confirmation step with remaining A-levels' do
        let(:current_step) { :remove_a_level_subject_confirmation }
        let(:current_step_params) { { uuid: '123', confirmation: 'yes' } }

        it { is_expected.to be_at_step(:remove_a_level_subject_confirmation) }

        it 'branches back to add_a_level_to_a_list when A-levels remain' do
          expect(wizard).to branch_from(:remove_a_level_subject_confirmation).to(:add_a_level_to_a_list)
        end
      end

      context 'at remove_a_level_subject_confirmation step with no remaining A-levels' do
        before do
          state_store.write(
            a_level_subject_requirements: [],
          )
        end

        let(:current_step) { :remove_a_level_subject_confirmation }
        let(:current_step_params) { { uuid: '123', confirmation: 'yes' } }

        it 'exits to course_edit when no A-levels remain' do
          expect(wizard).to branch_from(:remove_a_level_subject_confirmation).to(:course_edit)
        end
      end
    end
  end

  describe '#next_step' do
    context 'from what_a_level_is_required' do
      let(:current_step) { :what_a_level_is_required }

      before do
        state_store.write(
          a_level_subject_requirements: [
            { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
          ],
          subject: 'maths',
          minimum_grade_required: 'A',
        )
      end

      it { is_expected.to be_at_step(:what_a_level_is_required) }

      it 'moves to add_a_level_to_a_list' do
        expect(wizard).to have_next_step(:add_a_level_to_a_list)
      end
    end

    context 'from add_a_level_to_a_list' do
      let(:current_step) { :add_a_level_to_a_list }

      before do
        state_store.write(
          a_level_subject_requirements: [
            { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
          ],
        )
      end

      context 'when adding another A-level' do
        let(:current_step_params) { { add_another_a_level: 'yes' } }

        before do
          state_store.write(
            a_level_subject_requirements: [
              { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
            ],
            add_another_a_level: 'yes',
          )
        end

        it 'loops back to what_a_level_is_required' do
          expect(wizard).to have_next_step(:what_a_level_is_required)
        end

        it 'branches to what_a_level_is_required' do
          expect(wizard).to branch_from(:add_a_level_to_a_list).to(:what_a_level_is_required)
        end
      end

      context 'when done adding A-levels' do
        let(:current_step_params) { { add_another_a_level: 'no' } }

        before do
          state_store.write(
            a_level_subject_requirements: [
              { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
            ],
            add_another_a_level: 'no',
          )
        end

        it 'proceeds to consider_pending_a_level' do
          expect(wizard).to have_next_step(:consider_pending_a_level)
        end

        it 'branches to consider_pending_a_level' do
          expect(wizard).to branch_from(:add_a_level_to_a_list).to(:consider_pending_a_level)
        end
      end

      context 'when maximum A-levels reached (4)' do
        before do
          state_store.write(
            a_level_subject_requirements: [
              { uuid: '1', subject: 'maths', minimum_grade_required: 'A' },
              { uuid: '2', subject: 'physics', minimum_grade_required: 'B' },
              { uuid: '3', subject: 'chemistry', minimum_grade_required: 'A' },
              { uuid: '4', subject: 'biology', minimum_grade_required: 'B' },
            ],
          )
        end

        it 'automatically proceeds to consider_pending_a_level' do
          expect(wizard).to have_next_step(:consider_pending_a_level)
        end
      end
    end

    context 'from consider_pending_a_level' do
      let(:current_step) { :consider_pending_a_level }

      before do
        state_store.write(
          a_level_subject_requirements: [
            { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
          ],
          pending_a_level: 'yes',
        )
      end

      it { is_expected.to be_at_step(:consider_pending_a_level) }

      it 'proceeds to a_level_equivalencies' do
        expect(wizard).to have_next_step(:a_level_equivalencies)
      end
    end

    context 'from a_level_equivalencies' do
      let(:current_step) { :a_level_equivalencies }

      before do
        state_store.write(
          a_level_subject_requirements: [
            { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
          ],
          pending_a_level: 'yes',
          accept_a_level_equivalency: 'yes',
        )
      end

      it { is_expected.to be_at_step(:a_level_equivalencies) }

      it 'exits to course_edit redirect' do
        expect(wizard).to have_next_step(:course_edit)
      end
    end

    context 'from remove_a_level_subject_confirmation' do
      let(:current_step) { :remove_a_level_subject_confirmation }

      before do
        state_store.write(
          a_level_subject_requirements: [
            { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
            { uuid: '456', subject: 'physics', minimum_grade_required: 'B' },
          ],
        )
      end

      context 'when A-levels remain after deletion' do
        let(:current_step_params) { { uuid: '123', confirmation: 'yes' } }

        it 'returns to add_a_level_to_a_list' do
          expect(wizard).to have_next_step(:add_a_level_to_a_list)
        end
      end

      context 'when no A-levels remain after deletion' do
        before do
          state_store.write(
            a_level_subject_requirements: [],
          )
        end

        let(:current_step_params) { { uuid: '123', confirmation: 'yes' } }

        it 'exits to course_edit' do
          expect(wizard).to have_next_step(:course_edit)
        end
      end
    end
  end

  describe '#previous_step' do
    context 'when on add_a_level_to_a_list step' do
      let(:current_step) { :add_a_level_to_a_list }

      before do
        state_store.write(
          a_level_subject_requirements: [
            { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
          ],
        )
      end

      it { is_expected.to be_at_step(:add_a_level_to_a_list) }

      it 'returns to what_a_level_is_required step' do
        expect(wizard).to have_previous_step(:what_a_level_is_required)
      end
    end

    context 'when on consider_pending_a_level step' do
      let(:current_step) { :consider_pending_a_level }

      before do
        state_store.write(
          a_level_subject_requirements: [
            { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
          ],
        )
      end

      it 'returns to add_a_level_to_a_list step' do
        expect(wizard).to have_previous_step(:add_a_level_to_a_list)
      end
    end

    context 'when on a_level_equivalencies step' do
      let(:current_step) { :a_level_equivalencies }

      before do
        state_store.write(
          a_level_subject_requirements: [
            { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
          ],
          pending_a_level: 'yes',
        )
      end

      it { is_expected.to be_at_step(:a_level_equivalencies) }

      it 'returns to consider_pending_a_level step' do
        expect(wizard).to have_previous_step(:consider_pending_a_level)
      end
    end

    context 'when on course_edit redirect step' do
      let(:current_step) { :course_edit }

      before do
        state_store.write(
          a_level_subject_requirements: [
            { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
          ],
          pending_a_level: 'yes',
          accept_a_level_equivalency: 'yes',
        )
      end

      it 'returns to a_level_equivalencies step' do
        expect(wizard).to have_previous_step(:a_level_equivalencies)
      end
    end

    context 'when on first step' do
      let(:current_step) { :what_a_level_is_required }

      before do
        state_store.write(a_level_subject_requirements: [])
      end

      it { is_expected.to be_at_step(:what_a_level_is_required) }

      it 'returns nil' do
        expect(wizard.previous_step).to be_nil
      end
    end
  end

  describe 'routing' do
    context 'course_edit redirect step' do
      let(:current_step) { :course_edit }

      it 'resolves to course edit page' do
        expect(wizard).to resolve_step(:course_edit).to(
          url_helpers.publish_provider_recruitment_cycle_course_path(
            provider_code: course.provider_code,
            recruitment_cycle_year: course.recruitment_cycle_year,
            course_code: course.course_code,
          ),
        )
      end
    end
  end

  describe 'validation and accessibility' do
    context 'when all steps are valid' do
      let(:current_step) { :course_edit }

      before do
        state_store.write(
          subject: 'maths',
          minimum_grade_required: 'A',
          a_level_subject_requirements: [
            { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
          ],
          add_another_a_level: 'no',
          pending_a_level: 'yes',
          accept_a_level_equivalency: 'yes',
        )
      end

      it { is_expected.to be_at_step(:course_edit) }
      it { is_expected.to be_valid_to(:course_edit) }

      it 'course_edit is accessible' do
        expect(wizard.valid_path_to?(:course_edit)).to be true
      end
    end

    context 'when step has invalid data' do
      let(:current_step) { :consider_pending_a_level }

      before do
        state_store.write(
          a_level_subject_requirements: [],
          pending_a_level: nil,
        )
      end

      it { expect(wizard).not_to be_valid_to(:course_edit) }

      it 'course_edit is not accessible due to invalid previous step' do
        expect(wizard.valid_path_to?(:course_edit)).to be false
      end
    end
  end

  describe '#step' do
    let(:current_step) { :what_a_level_is_required }

    before do
      state_store.write(
        a_level_subject_requirements: [
          { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
        ],
      )
    end

    it 'returns hydrated step object' do
      step = wizard.step(:add_a_level_to_a_list)
      expect(step).to be_instance_of(Steps::AddALevelToAList)
      expect(step.subjects.size).to eq(1)
    end

    it 'caches step objects' do
      step1 = wizard.step(:what_a_level_is_required)
      step2 = wizard.step(:what_a_level_is_required)
      expect(step1).to equal(step2)
    end
  end

  describe '#current_step' do
    let(:current_step) { :what_a_level_is_required }

    before do
      state_store.write(
        a_level_subject_requirements: [
          { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
        ],
      )
    end

    it { is_expected.to be_at_step(:what_a_level_is_required) }

    it 'returns hydrated current step' do
      step = wizard.current_step
      expect(step).to be_instance_of(Steps::WhatALevelIsRequired)
    end
  end

  describe 'redirect step' do
    let(:current_step) { :course_edit }

    it 'course_edit step is instance of Redirect step' do
      step = wizard.step(:course_edit)
      expect(step).to be_instance_of(DfE::Wizard::Redirect)
    end

    it 'redirect step is always valid' do
      expect(:course_edit).to be_valid_step.in(wizard)
    end

    it 'redirect step has no attributes' do
      step = wizard.step(:course_edit)
      expect(step.attributes).to be_empty
    end

    it 'redirect step does not appear in saved_path' do
      state_store.write(
        a_level_subject_requirements: [
          { uuid: '123', subject: 'maths', minimum_grade_required: 'A' },
        ],
        add_another_a_level: 'no',
        pending_a_level: 'yes',
        accept_a_level_equivalency: 'yes',
      )

      expect(wizard).to have_saved_path(
        %i[
          what_a_level_is_required
          add_a_level_to_a_list
          consider_pending_a_level
          a_level_equivalencies
        ],
      )
    end
  end
end
