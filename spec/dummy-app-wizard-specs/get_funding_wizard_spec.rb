require 'spec_helper'

RSpec.describe GetFundingWizard do
  subject(:wizard) do
    described_class.new(
      current_step: current_step,
      state_store: StateStores::GetFundingWizardStore.new(application_form)
    )
  end

  let(:application_form) { build(:application_form) }

  describe '#path_traversal' do
    context 'when applicant does not need funding' do
      let(:application_form) { build(:application_form, :with_funding_not_needed, funding_section_complete: true) }
      let(:current_step) { :review }

      it 'goes through academic_background, visa_requirement, and reaches review' do
        expect(wizard.path_traversal).to eq(%i[
          personal_details
          academic_background
          visa_requirement
          review
        ])
      end
    end

    context 'when applicant needs funding' do
      let(:application_form) { build(:application_form, :with_funding_needed, funding_section_complete: true) }

      context 'at get_funding step' do
        let(:current_step) { :get_funding }

        it 'includes the funding step in traversal' do
          expect(wizard.path_traversal).to eq(%i[
            personal_details
            academic_background
            get_funding
          ])
        end
      end

      context 'at review step' do
        let(:current_step) { :review }

        it 'includes get_funding step and skips visa_requirement if all complete' do
          expect(wizard.path_traversal).to eq(%i[
            personal_details
            academic_background
            get_funding
            review
          ])
        end
      end
    end

    context 'with explicit data' do
      let(:current_step) { :review }

      let(:custom_data) do
        {
          steps: {
            academic_background: { needs_funding: true },
            get_funding: { complete: true },
            visa_requirement: { needs_support: false }
          }
        }
      end

      it 'resolves path using the explicit data' do
        expected = %i[
          personal_details
          academic_background
          get_funding
          review
        ]
        expect(wizard.steps_processor.path_traversal(:review, custom_data)).to eq(expected)
      end
    end
  end

  describe '#next_step' do
    context 'from personal_details → academic_background' do
      let(:current_step) { :personal_details }

      it 'advances to academic_background' do
        expect(wizard.next_step).to eq(:academic_background)
      end
    end

    context 'from academic_background with needs_funding = true' do
      let(:application_form) { build(:application_form, :with_funding_needed) }
      let(:current_step) { :academic_background }

      it 'routes to get_funding step' do
        expect(wizard.next_step).to eq(:get_funding)
      end
    end

    context 'from academic_background with needs_funding = false' do
      let(:application_form) { build(:application_form, :with_funding_not_needed) }
      let(:current_step) { :academic_background }

      it 'routes to visa_requirement' do
        expect(wizard.next_step).to eq(:visa_requirement)
      end
    end

    context 'from get_funding step' do
      let(:application_form) { build(:application_form, :with_funding_needed, funding_section_complete: true) }
      let(:current_step) { :get_funding }

      it 'routes to review step directly' do
        expect(wizard.next_step).to eq(:review)
      end
    end

    context 'from visa_requirement with funding incomplete' do
      let(:application_form) { build(:application_form, :with_funding_needed, funding_section_complete: false) }
      let(:current_step) { :visa_requirement }

      it 'cycles back to get_funding' do
        expect(wizard.next_step).to eq(:get_funding)
      end
    end

    context 'from visa_requirement with support need' do
      let(:application_form) do
        build(:application_form, :with_funding_not_needed, needs_support: true, funding_section_complete: true)
      end
      let(:current_step) { :visa_requirement }

      it 'goes to additional_support' do
        expect(wizard.next_step).to eq(:additional_support)
      end
    end

    context 'from visa_requirement with all done' do
      let(:application_form) do
        build(:application_form, :with_funding_not_needed, funding_section_complete: true, needs_support: false)
      end
      let(:current_step) { :visa_requirement }

      it 'proceeds to review' do
        expect(wizard.next_step).to eq(:review)
      end
    end
  end

  describe '#previous_step' do
    context 'from academic_background' do
      let(:current_step) { :academic_background }

      it 'goes back to personal_details' do
        expect(wizard.previous_step).to eq(:personal_details)
      end
    end

    context 'from get_funding' do
      let(:application_form) { build(:application_form, :with_funding_needed) }
      let(:current_step) { :get_funding }

      it 'goes back to academic_background' do
        expect(wizard.previous_step).to eq(:academic_background)
      end
    end

    context 'from visa_requirement after academic_background (no funding)' do
      let(:application_form) { build(:application_form, :with_funding_not_needed) }
      let(:current_step) { :visa_requirement }

      it 'goes back to academic_background' do
        expect(wizard.previous_step).to eq(:academic_background)
      end
    end

    context 'from review when came from get_funding' do
      let(:application_form) do
        build(:application_form, :with_funding_needed, funding_section_complete: true)
      end
      let(:current_step) { :review }

      it 'goes back to get_funding' do
        expect(wizard.previous_step).to eq(:get_funding)
      end
    end

    context 'from review when no funding path taken' do
      let(:application_form) do
        build(:application_form, :with_funding_not_needed, funding_section_complete: true)
      end
      let(:current_step) { :review }

      it 'goes back to visa_requirement' do
        expect(wizard.previous_step).to eq(:visa_requirement)
      end
    end
  end

  describe '#to_doc' do
    let(:current_step) { :personal_details }
    let(:application_form) { build(:application_form) }

    it 'returns a Graphviz document object' do
      expect(wizard.to_doc).to respond_to(:output)
    end
  end
end
