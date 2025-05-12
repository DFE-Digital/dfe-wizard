RSpec.feature 'Personal information wizard', type: :feature do
  before do
    visit root_path
    click_link_or_button 'Wizards'
    click_link_or_button 'Personal Information Wizard'
  end

  scenario 'when user is British' do
    choose 'British'
    click_link_or_button 'Continue'
    expect(page).to have_current_path('/personal-information/review')
  end

  scenario 'when user is Irish' do
    choose 'Irish'
    click_link_or_button 'Continue'
    expect(page).to have_current_path('/personal-information/review')
  end

  scenario 'when user is not British/Irish and has right to work or study' do
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
