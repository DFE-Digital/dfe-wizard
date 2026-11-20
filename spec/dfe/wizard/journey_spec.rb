RSpec.describe 'the journey of a wizard' do
  let(:state_store) { CourseChange::StateStore.new }

  it 'is nil by default, so wizards built without it are unchanged' do
    wizard = CourseChange::Wizard.new(state_store:, current_step: :level)

    expect(wizard.journey).to be_nil
    expect(wizard.next_step).to eq(:subject)
  end

  it 'is the journey the wizard was built with, from a Symbol or String' do
    expect(CourseChange::Wizard.new(state_store:, journey: :edit).journey).to eq(:edit)
    expect(CourseChange::Wizard.new(state_store:, journey: 'edit').journey).to eq(:edit)
  end
end
