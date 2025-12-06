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
      'First name' => 'John',
      'Last name' => 'Smith',
      'Date of birth' => '1 November 1975',
      'Nationalities' => 'British',
    )
    click_back_link
    then_i_should_be_on_the_nationality_step
    click_back_link
    then_i_should_be_on_the_name_and_dob_step
  end

  scenario 'when user is Irish' do
    when_i_select_nationality('Irish')
    and_i_continue
    then_i_should_be_on_the_review_step

    review_summary_check_for(
      'First name' => 'John',
      'Last name' => 'Smith',
      'Date of birth' => '1 November 1975',
      'Nationalities' => 'Irish',
    )
  end

  scenario 'when user is not British/Irish and has right to work or study' do
    when_i_select_other_nationality('Italian')
    and_i_continue

    then_i_should_be_on_the_right_to_work_or_study_step
    click_back_link
    then_i_should_be_on_the_nationality_step

    and_i_continue
    when_i_answer_right_to_work_or_study('Yes')
    and_i_continue

    then_i_should_be_on_the_immigration_status_step
    click_back_link
    then_i_should_be_on_the_right_to_work_or_study_step

    and_i_continue
    when_i_select_immigration_status('Skilled Worker visa')
    and_i_continue

    then_i_should_be_on_the_review_step
    review_summary_check_for(
      'First name' => 'John',
      'Last name' => 'Smith',
      'Date of birth' => '1 November 1975',
      'Nationalities' => 'Other',
      'Other nationality' => 'Italian',
      'Right to work or study?' => 'Yes',
      'Immigration status' => 'Skilled worker visa',
    )
    click_back_link
    then_i_should_be_on_the_immigration_status_step
    click_back_link
    then_i_should_be_on_the_right_to_work_or_study_step
    click_back_link
    then_i_should_be_on_the_nationality_step
  end

  scenario 'when user is not British/Irish and does not have right to work or study' do
    when_i_select_other_nationality('Italian')
    and_i_continue

    then_i_should_be_on_the_right_to_work_or_study_step

    when_i_answer_right_to_work_or_study('No')
    and_i_continue

    then_i_should_be_on_the_review_step
    review_summary_check_for(
      'First name' => 'John',
      'Last name' => 'Smith',
      'Date of birth' => '1 November 1975',
      'Nationalities' => 'Other',
      'Other nationality' => 'Italian',
      'Right to work or study?' => 'No',
    )
    click_back_link
    then_i_should_be_on_the_right_to_work_or_study_step
    click_back_link
    then_i_should_be_on_the_nationality_step
  end

  context 'Return to review/change flows' do
    scenario 'British flow: change name and date of birth from review, return to review' do
      when_i_select_nationality('British')
      and_i_continue
      then_i_should_be_on_the_review_step

      review_summary_check_for(
        'First name' => 'John',
        'Last name' => 'Smith',
        'Date of birth' => '1 November 1975',
        'Nationalities' => 'British',
      )

      when_i_change_answer('First name')
      then_i_should_be_on_the_name_and_dob_step(return_to_review: 'name_and_date_of_birth')

      fill_in 'First name', with: 'Alice'
      fill_in 'Last name', with: 'Liddell'
      fill_in 'Day', with: '2'
      fill_in 'Month', with: '12'
      fill_in 'Year', with: '1980'
      and_i_continue

      then_i_should_be_on_the_review_step
      review_summary_check_for(
        'First name' => 'Alice',
        'Last name' => 'Liddell',
        'Date of birth' => '2 December 1980',
        'Nationalities' => 'British',
      )

      click_back_link
      then_i_should_be_on_the_nationality_step
      click_back_link
      then_i_should_be_on_the_name_and_dob_step
    end

    context 'Italian flow' do
      background do
        when_i_select_other_nationality('Italian')
        and_i_continue
        when_i_answer_right_to_work_or_study('Yes')
        and_i_continue
        when_i_select_immigration_status('Skilled Worker visa')
        and_i_continue
        then_i_should_be_on_the_review_step
      end

      scenario 'change immigration status, keep answer the same, return to review' do
        review_summary_check_for(
          'First name' => 'John',
          'Last name' => 'Smith',
          'Date of birth' => '1 November 1975',
          'Nationalities' => 'Other',
          'Other nationality' => 'Italian',
          'Right to work or study?' => 'Yes',
          'Immigration status' => 'Skilled worker visa',
        )

        when_i_change_answer('Immigration status')
        then_i_should_be_on_the_immigration_status_step(return_to_review: 'immigration_status')
        when_i_select_immigration_status('Skilled Worker visa')
        and_i_continue

        then_i_should_be_on_the_review_step
        review_summary_check_for(
          'First name' => 'John',
          'Last name' => 'Smith',
          'Date of birth' => '1 November 1975',
          'Nationalities' => 'Other',
          'Other nationality' => 'Italian',
          'Right to work or study?' => 'Yes',
          'Immigration status' => 'Skilled worker visa',
        )

        click_back_link
        then_i_should_be_on_the_immigration_status_step
        click_back_link
        then_i_should_be_on_the_right_to_work_or_study_step
      end

      scenario 'change right to work, switch to No (skips immigration), return to review' do
        when_i_change_answer('Right to work or study?')
        then_i_should_be_on_the_right_to_work_or_study_step(return_to_review: 'right_to_work_or_study')
        when_i_answer_right_to_work_or_study('No')
        and_i_continue

        then_i_should_be_on_the_review_step
        review_summary_check_for(
          'First name' => 'John',
          'Last name' => 'Smith',
          'Date of birth' => '1 November 1975',
          'Nationalities' => 'Other',
          'Other nationality' => 'Italian',
          'Right to work or study?' => 'No',
        )

        when_i_change_answer('Right to work or study?')
        then_i_should_be_on_the_right_to_work_or_study_step(return_to_review: 'right_to_work_or_study')
        click_back_link
        then_i_should_be_on_the_review_step
      end

      scenario 'change right to work from Yes to No and walk forward' do
        when_i_change_answer('Right to work or study?')
        then_i_should_be_on_the_right_to_work_or_study_step(return_to_review: 'right_to_work_or_study')
        when_i_answer_right_to_work_or_study('No')
        and_i_continue

        then_i_should_be_on_the_review_step
        review_summary_check_for(
          'First name' => 'John',
          'Last name' => 'Smith',
          'Date of birth' => '1 November 1975',
          'Nationalities' => 'Other',
          'Other nationality' => 'Italian',
          'Right to work or study?' => 'No',
        )

        click_back_link
        then_i_should_be_on_the_right_to_work_or_study_step
        click_back_link
        then_i_should_be_on_the_nationality_step
      end
    end

    scenario 'change right to work from No to Yes, fill immigration status, then review' do
      when_i_select_other_nationality('Italian')
      and_i_continue
      when_i_answer_right_to_work_or_study('No')
      and_i_continue
      then_i_should_be_on_the_review_step

      when_i_change_answer('Right to work or study?')
      then_i_should_be_on_the_right_to_work_or_study_step(return_to_review: 'right_to_work_or_study')
      when_i_answer_right_to_work_or_study('Yes')
      and_i_continue

      then_i_should_be_on_the_immigration_status_step
      when_i_select_immigration_status('Skilled Worker visa')
      and_i_continue

      then_i_should_be_on_the_review_step
      review_summary_check_for(
        'First name' => 'John',
        'Last name' => 'Smith',
        'Date of birth' => '1 November 1975',
        'Nationalities' => 'Other',
        'Other nationality' => 'Italian',
        'Right to work or study?' => 'Yes',
        'Immigration status' => 'Skilled worker visa',
      )

      click_back_link
      then_i_should_be_on_the_immigration_status_step
      click_back_link
      then_i_should_be_on_the_right_to_work_or_study_step
      click_back_link
      then_i_should_be_on_the_nationality_step
    end
  end

  scenario 'documentation generation' do
    when_i_generate_documentation_for_personal_information_wizard
    and_the_generated_files_match_expected_fixture
  end

  def when_i_generate_documentation_for_personal_information_wizard
    @generated_directory = Rails.root.join('tmp')

    PersonalInformationWizard.new(
      state_store: StateStores::PersonalInformation.new,
    )
                             .documentation
                             .generate_all(@generated_directory)
  end

  def and_the_generated_files_match_expected_fixture
    generated_markdown = File.read(File.join(@generated_directory, 'personal_information_wizard.md'))
    generated_mermaid = File.read(File.join(@generated_directory, 'personal_information_wizard.mmd'))
    generated_graphviz = File.read(File.join(@generated_directory, 'personal_information_wizard.dot'))

    fixture_markdown = File.read('spec/fixtures/documentation/markdown/personal_information_wizard.md')
    fixture_mermaid = File.read('spec/fixtures/documentation/mermaid/personal_information_wizard.mmd')
    fixture_graphviz = File.read('spec/fixtures/documentation/graphviz/personal_information_wizard.dot')

    expect(normalize_whitespace(generated_markdown)).to eq(normalize_whitespace(fixture_markdown))
    expect(normalize_whitespace(generated_mermaid)).to eq(normalize_whitespace(fixture_mermaid))
    expect(normalize_whitespace(generated_graphviz)).to eq(normalize_whitespace(fixture_graphviz))
  end

  def normalize_whitespace(content)
    content
      .strip
      # Remove/normalize timestamps
      .gsub(/\*\*Generated:\*\*.*?Z/, '**Generated:** NORMALIZED')
      .gsub(/\s+/, ' ')
      .gsub(/\n\s*\n+/, "\n\n")
  end

  def given_i_start_the_personal_information_wizard
    visit root_path
    click_link_or_button 'Wizards'
    click_link_or_button 'Personal Information Wizard'
  end

  def and_i_complete_the_name_and_date_of_birth_step
    then_i_should_be_on_the_name_and_dob_step
    click_link_or_button 'Continue'
    expect(page).to have_content('There is a problem')
    fill_in 'First name', with: 'John'
    fill_in 'Last name', with: 'Smith'
    fill_in 'Day', with: '1'
    fill_in 'Month', with: '11'
    fill_in 'Year', with: '1975'
    and_i_continue
  end

  def then_i_should_be_on_the_name_and_dob_step(args = {})
    expect(page).to have_current_path(personal_information_name_and_date_of_birth_path(args))
    expect(page).to have_content('First name')
    expect(page).to have_content('Last name')
  end

  def then_i_should_be_on_the_nationality_step(args = {})
    expect(page).to have_current_path(personal_information_nationality_path(args))
    expect(page).to have_content('What is your nationality?')
  end

  def then_i_should_be_on_the_right_to_work_or_study_step(args = {})
    expect(page).to have_current_path(personal_information_right_to_work_or_study_path(args))
    expect(page).to have_content('Right to work or study?')
  end

  def then_i_should_be_on_the_immigration_status_step(args = {})
    expect(page).to have_current_path(personal_information_immigration_status_path(args))
    expect(page).to have_content('Select your immigration status')
  end

  def then_i_should_be_on_the_review_step
    expect(page).to have_current_path(personal_information_review_path)
    expect(page).to have_content('Check your answers')
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

  def click_back_link
    click_link 'Back'
  end

  def review_summary_check_for(fields_and_answers)
    within('.govuk-summary-list') do
      fields_and_answers.each do |field, answer|
        expect(page).to have_text(field)
        expect(page).to have_text(answer)
      end
    end
  end

  def when_i_change_answer(field_label)
    expect(page).to have_content('Check your answers')
    row = find('.govuk-summary-list__key', text: field_label, exact_text: true).find(:xpath, '..')
    within(row) do
      row.all('a.govuk-link').first.click
    end
  end
end
