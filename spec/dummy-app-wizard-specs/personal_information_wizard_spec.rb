RSpec.describe PersonalInformationWizard do
  subject(:wizard) do
    described_class.new(
      current_step:,
      state_store: StateStores::PersonalInformation.new(application_form),
    )
  end

  describe '#path_traversal' do
    context 'when British national' do
      let(:application_form) { build(:application_form, :british_national) }

      context 'at nationality step' do
        let(:current_step) { :nationality }

        it 'returns path from start to nationality' do
          expect(wizard.path_traversal).to eq(%i[name_and_date_of_birth nationality])
        end
      end

      context 'at review step' do
        let(:current_step) { :review }

        it 'returns direct path from start to review via nationality' do
          expect(wizard.path_traversal).to eq(%i[name_and_date_of_birth nationality review])
        end
      end
    end

    context 'when non-UK national' do
      context 'with right to work' do
        let(:application_form) do
          build(:application_form, :non_uk_national, :with_right_to_work)
        end

        context 'at right_to_work_or_study step' do
          let(:current_step) { :right_to_work_or_study }

          it 'returns path from start to right_to_work_or_study' do
            expected_path = %i[name_and_date_of_birth nationality right_to_work_or_study]
            expect(wizard.path_traversal).to eq(expected_path)
          end
        end

        context 'at review step' do
          let(:current_step) { :review }

          it 'returns path from start to review via right_to_work_or_study' do
            expected_path = %i[name_and_date_of_birth nationality right_to_work_or_study review]
            expect(wizard.path_traversal).to eq(expected_path)
          end
        end
      end

      context 'without right to work' do
        let(:application_form) do
          build(:application_form, :non_uk_national, :without_right_to_work)
        end

        context 'at immigration_status step' do
          let(:current_step) { :immigration_status }

          it 'returns path from start to immigration_status' do
            expected_path = %i[
              name_and_date_of_birth
              nationality
              right_to_work_or_study
              immigration_status
            ]
            expect(wizard.path_traversal).to eq(expected_path)
          end
        end

        context 'at review step' do
          let(:current_step) { :review }

          it 'returns full path from start to review' do
            expected_path = %i[
              name_and_date_of_birth
              nationality
              right_to_work_or_study
              immigration_status
              review
            ]
            expect(wizard.path_traversal).to eq(expected_path)
          end
        end
      end
    end

    context 'with explicit target step' do
      let(:application_form) { build(:application_form, :british_national) }
      let(:current_step) { :name_and_date_of_birth }

      it 'returns path to specified target' do
        expect(wizard.path_traversal(:review)).to eq(%i[name_and_date_of_birth nationality review])
      end
    end

    context 'with explicit data' do
      let(:application_form) { build(:application_form, :british_national) }
      let(:current_step) { :name_and_date_of_birth }

      let(:non_uk_data) do
        {
          steps: {
            nationality: { nationalities: ['french'] },
            right_to_work_or_study: { right_to_work_or_study: 'no' },
          },
        }
      end

      it 'uses explicit data for traversal' do
        expected_path = %i[
          name_and_date_of_birth
          nationality
          right_to_work_or_study
          immigration_status
        ]
        expect(wizard.path_traversal(:immigration_status, non_uk_data)).to eq(expected_path)
      end
    end
  end

  describe '#next_step' do
    context 'from name_and_date_of_birth' do
      let(:current_step) { :name_and_date_of_birth }
      let(:application_form) { build(:application_form) }

      it 'moves to nationality' do
        expect(wizard.next_step).to eq(:nationality)
        expect(wizard.next_step_path).to eq('/personal-information/nationality')
      end
    end

    context 'from nationality' do
      let(:current_step) { :nationality }

      context 'UK national' do
        let(:application_form) { build(:application_form, :british_national) }

        it 'skips to review' do
          expect(wizard.next_step).to eq(:review)
          expect(wizard.next_step_path).to eq('/personal-information/review')
        end
      end

      context 'Irish national' do
        let(:application_form) { build(:application_form, :irish_national) }

        it 'skips to review' do
          expect(wizard.next_step).to eq(:review)
          expect(wizard.next_step_path).to eq('/personal-information/review')
        end
      end

      context 'non-UK national' do
        let(:application_form) { build(:application_form, :non_uk_national) }

        it 'proceeds to right_to_work_or_study' do
          expect(wizard.next_step).to eq(:right_to_work_or_study)
          expect(wizard.next_step_path).to eq('/personal-information/right-to-work-or-study')
        end
      end
    end

    context 'from right_to_work_or_study' do
      let(:current_step) { :right_to_work_or_study }

      context 'with right to work' do
        let(:application_form) { build(:application_form, :with_right_to_work) }

        it 'proceeds to review' do
          expect(wizard.next_step).to eq(:review)
          expect(wizard.next_step_path).to eq('/personal-information/review')
        end
      end

      context 'without right to work' do
        let(:application_form) { build(:application_form, :without_right_to_work) }

        it 'proceeds to immigration_status' do
          expect(wizard.next_step).to eq(:immigration_status)
          expect(wizard.next_step_path).to eq('/personal-information/immigration-status')
        end
      end
    end

    context 'from immigration_status' do
      let(:current_step) { :immigration_status }
      let(:application_form) { build(:application_form) }

      it 'proceeds to review' do
        expect(wizard.next_step).to eq(:review)
        expect(wizard.next_step_path).to eq('/personal-information/review')
      end
    end
  end

  describe '#previous_step' do
    context 'when on immigration_status step' do
      let(:current_step) { :immigration_status }
      let(:application_form) { build(:application_form, :non_uk_national, :without_right_to_work) }

      it 'returns to right_to_work_or_study step' do
        expect(wizard.previous_step).to eq(:right_to_work_or_study)
      end
    end

    context 'when on right_to_work_or_study step' do
      let(:current_step) { :right_to_work_or_study }
      let(:application_form) { build(:application_form, :non_uk_national) }

      it 'returns to nationality step' do
        expect(wizard.previous_step).to eq(:nationality)
        expect(wizard.previous_step_path).to eq('/personal-information/nationality')
      end
    end

    context 'when on nationality step' do
      let(:current_step) { :nationality }
      let(:application_form) { build(:application_form) }

      it 'returns to name_and_date_of_birth step' do
        expect(wizard.previous_step).to eq(:name_and_date_of_birth)
        expect(wizard.previous_step_path).to eq('/personal-information/name-and-date-of-birth')
      end
    end

    context 'when on review step with UK nationality' do
      let(:current_step) { :review }
      let(:application_form) { build(:application_form, :british_national) }

      it 'returns to nationality step' do
        expect(wizard.previous_step).to eq(:nationality)
        expect(wizard.previous_step_path).to eq('/personal-information/nationality')
      end
    end

    context 'when on review step with non-UK nationality but with right to work' do
      let(:current_step) { :review }
      let(:application_form) { build(:application_form, :non_uk_national, :with_right_to_work) }

      it 'returns to right_to_work_or_study step' do
        expect(wizard.previous_step).to eq(:right_to_work_or_study)
        expect(wizard.previous_step_path).to eq('/personal-information/right-to-work-or-study')
      end
    end

    context 'when on first step' do
      let(:current_step) { :name_and_date_of_birth }
      let(:application_form) { build(:application_form) }

      it 'returns nil' do
        expect(wizard.previous_step).to be_nil
        expect(wizard.previous_step_path).to be_nil
      end
    end
  end
end
