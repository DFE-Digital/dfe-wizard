RSpec.feature 'Register ECT wizard', type: :feature do
  background do
    given_i_start_the_register_ect_wizard
    then_i_should_be_on_the_find_ect_step
  end

  scenario 'happy path with provider-led training' do
    when_i_find_an_ect(trn: '1234567', day: '1', month: '11', year: '1980')
    then_i_should_be_on_the_review_ect_details_step
    when_i_confirm_ect_details_and_enter_name('Pat Ect')
    and_i_continue

    then_i_should_be_on_the_email_address_step
    when_i_enter_email('ect@example.com')
    and_i_continue

    then_i_should_be_on_the_start_date_step
    when_i_enter_start_date(day: '17', month: '9', year: '2024')
    and_i_continue

    then_i_should_be_on_the_working_pattern_step
    when_i_choose_working_pattern('Full time')
    and_i_continue

    then_i_should_be_on_the_state_school_appropriate_body_step
    when_i_enter_appropriate_body_name('Example Appropriate Body')
    and_i_continue

    then_i_should_be_on_the_programme_type_step
    when_i_choose_training_programme('Provider-led')
    and_i_continue

    then_i_should_be_on_the_lead_provider_step
    when_i_choose_lead_provider('Teach First')
    and_i_continue

    then_i_should_be_on_the_check_answers_step
    and_i_see_the_check_answers_summary(
      'Name' => 'Pat Ect',
      'Teacher Reference Number (TRN)' => '1234567',
      'Email address' => 'ect@example.com',
      'School start date' => '17 September 2024',
      'Working pattern' => 'Full time',
      'Appropriate body' => 'Example Appropriate Body',
      'Training programme' => 'Provider-led',
      'Lead provider' => 'Teach First',
    )
    and_i_confirm_details

    then_i_should_be_on_the_confirmation_step
    and_i_see_the_confirmation_summary
  end

  scenario 'when TRN is not found' do
    when_i_find_an_ect(trn: '0000000', day: '1', month: '11', year: '1980')
    then_i_should_be_on_the_trn_not_found_step
    when_i_try_again
    then_i_should_be_on_the_find_ect_step
  end

  scenario 'skipping steps' do
    when_i_go_to_the_programme_type_step_directly
    then_i_see_a_404

    when_i_go_to_the_check_answers_step_directly
    then_i_see_a_404

    when_i_go_to_the_confirmation_step_directly
    then_i_see_a_404
  end

  def given_i_start_the_register_ect_wizard
    visit root_path
    click_link_or_button 'Wizards'
    click_link_or_button 'Register ECT Wizard'
  end

  def then_i_should_be_on_the_find_ect_step
    expect(page).to have_current_path(register_ect_find_ect_path)
    expect(page).to have_content('Find an ECT')
  end

  def when_i_find_an_ect(trn:, day:, month:, year:)
    fill_in 'Teacher reference number (TRN)', with: trn
    fill_in 'Day', with: day
    fill_in 'Month', with: month
    fill_in 'Year', with: year
    and_i_continue
  end

  def then_i_should_be_on_the_review_ect_details_step
    expect(page).to have_current_path(register_ect_review_ect_details_path)
    expect(page).to have_content('Review ECT details')
  end

  def when_i_confirm_ect_details_and_enter_name(name)
    choose 'No, they changed their name or it\'s spelt wrong'
    fill_in 'Enter the correct full name', with: name
  end

  def then_i_should_be_on_the_email_address_step
    expect(page).to have_current_path(register_ect_email_address_path)
    expect(page).to have_content('email address')
  end

  def when_i_enter_email(email)
    fill_in 'Email address', with: email
  end

  def then_i_should_be_on_the_start_date_step
    expect(page).to have_current_path(register_ect_start_date_path)
    expect(page).to have_content('start teaching as an ECT')
  end

  def when_i_enter_start_date(day:, month:, year:)
    fill_in 'Day', with: day
    fill_in 'Month', with: month
    fill_in 'Year', with: year
  end

  def then_i_should_be_on_the_working_pattern_step
    expect(page).to have_current_path(register_ect_working_pattern_path)
    expect(page).to have_content('working pattern')
  end

  def when_i_choose_working_pattern(value)
    choose value
  end

  def then_i_should_be_on_the_state_school_appropriate_body_step
    expect(page).to have_current_path(register_ect_state_school_appropriate_body_path)
    expect(page).to have_content('appropriate body')
  end

  def when_i_enter_appropriate_body_name(name)
    fill_in 'Enter appropriate body name', with: name
  end

  def then_i_should_be_on_the_programme_type_step
    expect(page).to have_current_path(register_ect_programme_type_path)
    expect(page).to have_content('training programme')
  end

  def when_i_choose_training_programme(value)
    choose value
  end

  def then_i_should_be_on_the_lead_provider_step
    expect(page).to have_current_path(register_ect_lead_provider_path)
    expect(page).to have_content('lead provider')
  end

  def when_i_choose_lead_provider(name)
    choose name
  end

  def then_i_should_be_on_the_check_answers_step
    expect(page).to have_current_path(register_ect_check_answers_path)
    expect(page).to have_content('Check your answers before submitting')
  end

  def and_i_see_the_check_answers_summary(fields_and_answers)
    fields_and_answers.each do |field, answer|
      expect(page).to have_text(field)
      expect(page).to have_text(answer)
    end
  end

  def and_i_confirm_details
    click_link_or_button 'Confirm details'
  end

  def then_i_should_be_on_the_confirmation_step
    expect(page).to have_current_path(register_ect_confirmation_path)
    expect(page).to have_content('You have saved')
  end

  def and_i_see_the_confirmation_summary
    expect(page).to have_content('Assign a mentor')
  end

  def then_i_should_be_on_the_trn_not_found_step
    expect(page).to have_current_path(register_ect_trn_not_found_path)
    expect(page).to have_content('unable to match the ECT with the TRN you provided')
  end

  def when_i_try_again
    click_link_or_button 'Try again'
  end

  def when_i_go_to_the_programme_type_step_directly
    visit register_ect_programme_type_path
  end

  def when_i_go_to_the_check_answers_step_directly
    visit register_ect_check_answers_path
  end

  def when_i_go_to_the_confirmation_step_directly
    visit register_ect_confirmation_path
  end

  def then_i_see_a_404
    expect(page.status_code).to eq(404)
  end

  def and_i_continue
    if page.has_button?('Continue')
      click_button 'Continue'
    else
      click_button 'Confirm and continue'
    end
  end
end
