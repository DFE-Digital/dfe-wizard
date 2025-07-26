RSpec.feature 'Personal information wizard', type: :feature do
  background do
    given_i_start_the_personal_information_wizard
    and_i_complete_the_name_and_date_of_birth_step
    then_i_should_be_on_the_nationality_step
  end

  scenario 'when user is British' do
    when_i_select_nationality('British')
    and_i_continue
    then_i_should_be_on_the_review_step

    review_summary_check_for(
      "First name" => "John",
      "Last name" => "Smith",
      "Date of birth" => "1 November 1975",
      "Nationalities" => "British"
    )
  end

  scenario 'when user is Irish' do
    when_i_select_nationality('Irish')
    and_i_continue
    then_i_should_be_on_the_review_step

    review_summary_check_for(
      "First name" => "John",
      "Last name" => "Smith",
      "Date of birth" => "1 November 1975",
      "Nationalities" => "Irish"
    )
  end

  scenario 'when user is not British/Irish and has right to work or study' do
    when_i_select_other_nationality('Italian')
    and_i_continue

    expect(page).to have_current_path(personal_information_right_to_work_or_study_path)

    when_i_answer_right_to_work_or_study('Yes')
    and_i_continue

    expect(page).to have_current_path(personal_information_immigration_status_path)

    when_i_select_immigration_status('Skilled Worker visa')
    and_i_continue

    then_i_should_be_on_the_review_step

    review_summary_check_for(
      "First name" => "John",
      "Last name" => "Smith",
      "Date of birth" => "1 November 1975",
      "Nationalities" => "Other",
      "Other nationality" => "Italian",
      "Right to work or study?" => "Yes",
      "Immigration status" => "Skilled worker visa"
    )
  end

  scenario 'when user is not British/Irish and does not have right to work or study' do
    when_i_select_other_nationality('Italian')
    and_i_continue

    expect(page).to have_current_path(personal_information_right_to_work_or_study_path)

    when_i_answer_right_to_work_or_study('No')
    and_i_continue

    then_i_should_be_on_the_review_step

    review_summary_check_for(
      "First name" => "John",
      "Last name" => "Smith",
      "Date of birth" => "1 November 1975",
      "Nationalities" => "Other",
      "Other nationality" => "Italian",
      "Right to work or study?" => "No"
    )
  end

  # === Step Definitions ===

  def given_i_start_the_personal_information_wizard
    visit root_path
    click_link_or_button 'Wizards'
    click_link_or_button 'Personal Information Wizard'
  end

  def and_i_complete_the_name_and_date_of_birth_step
    expect(page).to have_current_path(personal_information_name_and_date_of_birth_path)

    # Trigger validation first
    click_link_or_button 'Continue'
    expect(page).to have_content('There is a problem')

    fill_in 'First name', with: 'John'
    fill_in 'Last name', with: 'Smith'
    fill_in 'Day', with: '1'
    fill_in 'Month', with: '11'
    fill_in 'Year', with: '1975'

    click_link_or_button 'Continue'
  end

  def then_i_should_be_on_the_nationality_step
    expect(page).to have_current_path(personal_information_nationality_path)
    expect(page).to have_content('Nationalities')
  end

  def when_i_select_nationality(value)
    check value
  end

  def when_i_select_other_nationality(value)
    check 'Other'
    fill_in 'Enter your nationality', with: value
  end

  def when_i_answer_right_to_work_or_study(answer)
    choose answer
  end

  def when_i_select_immigration_status(value)
    choose value
  end

  def and_i_continue
    click_link_or_button 'Continue'
  end

  def then_i_should_be_on_the_review_step
    expect(page).to have_current_path(personal_information_review_path)
    expect(page).to have_content('Check your answers')
  end

  def review_summary_check_for(fields_and_answers)
    within(".govuk-summary-list") do
      fields_and_answers.each do |field, answer|
        expect(page).to have_text(field)
        expect(page).to have_text(answer)
      end
    end
  end
end
