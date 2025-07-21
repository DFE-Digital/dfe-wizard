RSpec.feature 'Personal information wizard', type: :feature do
  before do
    visit root_path

    save_and_open_page

    click_link_or_button 'Wizards'
    click_link_or_button 'Personal Information Wizard'

    expect(page).to have_current_path(personal_information_name_and_date_of_birth_path)

    fill_in 'First name', with: 'John'
    fill_in 'Last name', with: 'Smith'
    fill_in 'Day', with: '1'
    fill_in 'Month', with: '11'
    fill_in 'Year', with: '1975'

    click_link_or_button 'Continue'
  end

  scenario 'when user is British' do
    expect(page).to have_content('Nationality')
    choose 'British'
    click_link_or_button 'Continue'
    expect(page).to have_current_path('/personal-information/review')
  end

  scenario 'when user is Irish' do
    expect(page).to have_content('Nationality')
    choose 'Irish'
    click_link_or_button 'Continue'
    expect(page).to have_current_path('/personal-information/review')
  end

  scenario 'when user is not British/Irish and has right to work or study' do
    expect(page).to have_content('Nationality')
    choose 'Other nationality'
    fill_in 'Other nationality', with: 'Italian'
    expect(page).to have_current_path('/personal-information/right-to-work-or-study')
    choose 'Yes'
    click_link_or_button 'Continue'
    expect(page).to have_current_path('/personal-information/immigration-status')
    choose 'Skilled Worker visa'
    click_link_or_button 'Continue'
    expect(page).to have_current_path('/personal-information/review')
  end

  scenario 'when user is not British/Irish and does not have right to work or study' do
    choose 'Other nationality'
    fill_in 'Other nationality', with: 'Italian'
    expect(page).to have_current_path('/personal-information/right-to-work-or-study')
    choose 'No'
    click_link_or_button 'Continue'
    expect(page).to have_current_path('/personal-information/review')
  end
end
