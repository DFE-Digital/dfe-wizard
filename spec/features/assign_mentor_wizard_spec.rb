RSpec.feature 'Assign mentor wizard', type: :feature do
  background do
    given_i_start_the_assign_mentor_wizard
    then_i_should_be_on_the_choose_mentor_step
  end

  scenario 'when the lead provider will provide training' do
    when_i_choose_an_existing_mentor('Alice Mentor')
    and_i_continue

    then_i_should_be_on_the_training_step
    and_i_continue

    then_i_should_be_on_the_confirmation_step
    and_i_see_the_confirmation_summary
    and_i_can_return_to_the_wizard_index
  end

  scenario 'when the lead provider will not provide training' do
    when_i_choose_an_existing_mentor('Bob Mentor')
    and_i_continue

    then_i_should_be_on_the_training_step
    when_i_click_the_not_providing_link

    then_i_should_be_on_the_lead_provider_step
    when_i_select_lead_provider('Teach First')
    and_i_continue

    then_i_should_be_on_the_confirmation_step
    and_i_see_the_confirmation_summary
  end

  def given_i_start_the_assign_mentor_wizard
    visit root_path
    click_link_or_button 'Wizards'
    click_link_or_button 'Assign Mentor Wizard'
  end

  def then_i_should_be_on_the_choose_mentor_step
    expect(page).to have_current_path(assign_mentor_who_will_be_the_mentor_path)
    expect(page).to have_content('Who will mentor Peter Davison?')
  end

  def when_i_choose_an_existing_mentor(name)
    choose name
  end

  def and_i_continue
    click_link_or_button 'Continue'
  end

  def then_i_should_be_on_the_training_step
    expect(page).to have_current_path(assign_mentor_can_receive_mentor_training_path)
    expect(page).to have_content('Peter Davison can receive mentor training')
  end

  def when_i_click_the_not_providing_link
    click_button 'DfE Training Provider will not be providing mentor training to Peter Davison'
  end

  def then_i_should_be_on_the_lead_provider_step
    expect(page).to have_current_path(assign_mentor_which_lead_provider_path)
    expect(page).to have_content('Which lead provider will be training Peter Davison?')
  end

  def when_i_select_lead_provider(name)
    choose name
  end

  def then_i_should_be_on_the_confirmation_step
    expect(page).to have_current_path(assign_mentor_confirmation_path)
    expect(page).to have_content("You've assigned")
  end

  def and_i_see_the_confirmation_summary
    expect(page).to have_content("You've assigned Alice Mentor as a mentor")
  end

  def and_i_can_return_to_the_wizard_index
    expect(page).to have_link('Back to your ECTs', href: wizards_path)
  end
end
