RSpec.feature 'Add course wizard', type: :feature do
  background do
    given_there_is_a_provider_with_schools_and_study_sites
    when_i_start_the_add_course_wizard
  end

  scenario 'primary course journey' do
    and_i_select_primary_on_the_level_step
    and_i_select_no_send_specialism
    then_i_should_be_on_the_subject_step

    and_i_select_primary_subject
    then_i_should_be_on_the_age_range_step

    and_i_select_age_range_11_to_16
    then_i_should_be_on_the_qualification_step

    and_i_select_qts_with_pgce
    and_i_continue_through_remaining_steps
    then_i_should_be_on_the_review_step

    and_i_click_create_course
    then_a_new_course_should_be_created
  end

  scenario 'secondary course journey' do
    and_i_select_secondary_on_the_level_step
    and_i_select_no_send_specialism
    then_i_should_be_on_the_subject_step

    and_i_select_first_secondary_subject
    and_i_select_second_secondary_subject
    then_i_should_be_on_the_age_range_step

    and_i_select_age_range_11_to_18
    then_i_should_be_on_the_qualification_step

    and_i_select_teacher_degree_apprenticeship
    and_i_continue_through_remaining_steps
    then_i_should_be_on_the_review_step

    and_i_click_create_course
    then_a_new_course_should_be_created
  end

  scenario 'further education course journey' do
    and_i_select_further_education_on_the_level_step
    then_i_should_be_on_the_age_range_step

    and_i_select_age_range_14_to_19
    then_i_should_be_on_the_qualification_step

    and_i_select_qts
    and_i_continue_through_remaining_steps
    then_i_should_be_on_the_review_step

    and_i_click_create_course
    then_a_new_course_should_be_created
  end

  scenario 'custom age range' do
    and_i_select_secondary_on_the_level_step
    and_i_select_no_send_specialism
    and_i_select_first_secondary_subject
    then_i_should_be_on_the_age_range_step

    and_i_select_another_age_range
    and_i_enter_custom_age_range_5_to_11
    then_i_should_be_on_the_qualification_step
  end

  scenario 'fee-based funding course' do
    and_i_select_secondary_on_the_level_step
    and_i_select_no_send_specialism
    and_i_select_first_secondary_subject
    and_i_select_age_range_11_to_18
    and_i_select_qts_with_pgce
    then_i_should_be_on_the_funding_type_step

    and_i_select_fee_no_salary
    then_i_should_be_on_the_study_pattern_step

    and_i_select_full_time_and_part_time
    then_i_should_be_on_the_placement_schools_step

    and_i_select_placement_school
    then_i_should_be_on_the_study_sites_step

    and_i_select_study_site
    then_i_should_be_on_the_student_visa_step

    and_i_select_can_sponsor_student_visa_yes
    then_i_should_be_on_the_visa_deadline_required_step

    and_i_select_visa_deadline_required_yes
    then_i_should_be_on_the_visa_deadline_at_step

    and_i_enter_visa_deadline_date
    then_i_should_be_on_the_start_date_step

    and_i_select_course_start_date
    then_i_should_be_on_the_review_step
  end

  scenario 'salary-based funding course' do
    and_i_select_secondary_on_the_level_step
    and_i_select_no_send_specialism
    and_i_select_first_secondary_subject
    and_i_select_age_range_11_to_18
    and_i_select_qts_with_pgce
    then_i_should_be_on_the_funding_type_step

    and_i_select_salary
    then_i_should_be_on_the_study_pattern_step

    and_i_select_full_time
    then_i_should_be_on_the_placement_schools_step

    and_i_select_placement_school
    then_i_should_be_on_the_study_sites_step

    and_i_select_study_site
    then_i_should_be_on_the_student_visa_step

    and_i_select_can_sponsor_student_visa_no
    then_i_should_be_on_the_skilled_worker_visa_step

    and_i_select_can_sponsor_skilled_worker_visa_yes
    then_i_should_be_on_the_visa_deadline_required_step

    and_i_select_visa_deadline_required_no
    then_i_should_be_on_the_start_date_step

    and_i_select_course_start_date
    then_i_should_be_on_the_review_step
  end

  scenario 'teaching apprenticeship funding' do
    and_i_select_secondary_on_the_level_step
    and_i_select_no_send_specialism
    and_i_select_first_secondary_subject
    and_i_select_age_range_11_to_18
    and_i_select_qts_with_pgce
    then_i_should_be_on_the_funding_type_step

    and_i_select_teaching_apprenticeship_with_salary
    then_i_should_be_on_the_placement_schools_step
  end

  scenario 'primary with send specialism' do
    and_i_select_primary_on_the_level_step
    and_i_select_yes_send_specialism
    then_i_should_be_on_the_age_range_step
  end

  scenario 'validation on level step' do
    and_i_try_to_submit_level_step_without_selection
    then_i_should_remain_on_the_level_step
    and_i_should_see_validation_error
  end

  scenario 'validation on subject step for secondary' do
    and_i_select_secondary_on_the_level_step
    and_i_select_no_send_specialism
    then_i_should_be_on_the_subject_step

    and_i_try_to_submit_subject_step_without_first_subject
    then_i_should_remain_on_the_subject_step
    and_i_should_see_first_subject_validation_error
  end

  scenario 'form data persists through all steps' do
    and_i_select_secondary_on_the_level_step
    and_i_select_no_send_specialism
    and_i_select_first_secondary_subject_mathematics
    and_i_click_continue

    when_i_navigate_back_to_subject_step
    then_the_first_subject_should_still_be_mathematics
    and_the_second_subject_should_be_empty
  end

  private

  def given_there_is_a_provider_with_schools_and_study_sites
    @provider = create(:provider, code: 'ABC123', recruitment_cycle_year: 2025)

    @school_one = create(:school, provider: @provider, name: 'Test School 1')
    @school_two = create(:school, provider: @provider, name: 'Test School 2')
    @study_siteone = create(:study_site, provider: @provider, name: 'Main Campus')
    @study_site_two = create(:study_site, provider: @provider, name: 'City Centre')
  end

  def when_i_start_the_add_course_wizard
    @state_key = SecureRandom.uuid
    visit step_recruitment_cycle_provider_add_course_courses_path(
      recruitment_cycle_year: 2025,
      provider_code: @provider.code,
      state_key: @state_key,
      step: :level,
    )
  end

  def and_i_select_primary_on_the_level_step
    choose 'Primary'
    click_button 'Continue'
  end

  def and_i_select_secondary_on_the_level_step
    choose 'Secondary'
    click_button 'Continue'
  end

  def and_i_select_further_education_on_the_level_step
    choose 'Further education'
    click_button 'Continue'
  end

  def and_i_select_no_send_specialism
    choose 'No'
    click_button 'Continue'
  end

  def and_i_select_yes_send_specialism
    choose 'Yes'
    click_button 'Continue'
  end

  def and_i_select_primary_subject
    choose 'Primary'
    click_button 'Continue'
  end

  def and_i_select_first_secondary_subject
    select 'English', from: 'course[first_subject]'
    click_button 'Continue'
  end

  def and_i_select_first_secondary_subject_mathematics
    select 'Mathematics', from: 'course[first_subject]'
  end

  def and_i_select_second_secondary_subject
    select 'Mathematics', from: 'course[second_subject]'
    click_button 'Continue'
  end

  def and_i_select_age_range_11_to_16
    choose '11 to 16'
    click_button 'Continue'
  end

  def and_i_select_age_range_11_to_18
    choose '11 to 18'
    click_button 'Continue'
  end

  def and_i_select_age_range_14_to_19
    choose '14 to 19'
    click_button 'Continue'
  end

  def and_i_select_another_age_range
    choose 'Another age range'
  end

  def and_i_enter_custom_age_range_5_to_11
    fill_in 'course[age_range_from]', with: '5'
    fill_in 'course[age_range_to]', with: '11'
    click_button 'Continue'
  end

  def and_i_select_qts_with_pgce
    choose 'QTS with PGCE'
    click_button 'Continue'
  end

  def and_i_select_qts_with_pgde
    choose 'QTS with PGDE'
    click_button 'Continue'
  end

  def and_i_select_qts
    choose 'QTS'
    click_button 'Continue'
  end

  def and_i_select_teacher_degree_apprenticeship
    choose 'Teacher degree apprenticeship (TDA) with QTS'
    click_button 'Continue'
  end

  def and_i_select_fee_no_salary
    choose 'Fee - no salary'
    click_button 'Continue'
  end

  def and_i_select_salary
    choose 'Salary'
    click_button 'Continue'
  end

  def and_i_select_teaching_apprenticeship_with_salary
    choose 'Teaching apprenticeship - with salary'
    click_button 'Continue'
  end

  def and_i_select_full_time
    check 'Full time'
    click_button 'Continue'
  end

  def and_i_select_full_time_and_part_time
    check 'Full time'
    check 'Part time'
    click_button 'Continue'
  end

  def and_i_select_placement_school
    check @school_one.name
    click_button 'Continue'
  end

  def and_i_select_study_site
    check study_site_one.name
    click_button 'Continue'
  end

  def and_i_select_can_sponsor_student_visa_yes
    choose 'Yes'
    click_button 'Continue'
  end

  def and_i_select_can_sponsor_student_visa_no
    choose 'No'
    click_button 'Continue'
  end

  def and_i_select_can_sponsor_skilled_worker_visa_yes
    choose 'Yes'
    click_button 'Continue'
  end

  def and_i_select_can_sponsor_skilled_worker_visa_no
    choose 'No'
    click_button 'Continue'
  end

  def and_i_select_visa_deadline_required_yes
    choose 'Yes'
    click_button 'Continue'
  end

  def and_i_select_visa_deadline_required_no
    choose 'No'
    click_button 'Continue'
  end

  def and_i_enter_visa_deadline_date
    fill_in 'course[visa_deadline_day]', with: '31'
    fill_in 'course[visa_deadline_month]', with: '12'
    fill_in 'course[visa_deadline_year]', with: '2024'
    click_button 'Continue'
  end

  def and_i_select_course_start_date
    choose 'course_start_date_september'
    click_button 'Continue'
  end

  def and_i_continue_through_remaining_steps
    and_i_should_be_on_the_funding_type_step
    and_i_select_fee_no_salary
    and_i_select_full_time
    and_i_select_placement_school
    and_i_select_study_site
    and_i_select_can_sponsor_student_visa_no
    and_i_select_can_sponsor_skilled_worker_visa_no
    and_i_select_course_start_date
  end

  def and_i_click_continue
    click_button 'Continue'
  end

  def and_i_click_create_course
    click_button 'Create course'
  end

  def and_i_try_to_submit_level_step_without_selection
    click_button 'Continue'
  end

  def and_i_try_to_submit_subject_step_without_first_subject
    click_button 'Continue'
  end

  def when_i_navigate_back_to_subject_step
    click_link 'Back'
  end

  def then_i_should_be_on_the_subject_step
    expect(page).to have_content('What subject')
  end

  def then_i_should_be_on_the_age_range_step
    expect(page).to have_content('What age range')
  end

  def then_i_should_be_on_the_qualification_step
    expect(page).to have_content('What qualification')
  end

  def then_i_should_be_on_the_funding_type_step
    expect(page).to have_content('What type of funding')
  end

  def then_i_should_be_on_the_study_pattern_step
    expect(page).to have_content('Study pattern')
  end

  def then_i_should_be_on_the_placement_schools_step
    expect(page).to have_content('Placement schools')
  end

  def then_i_should_be_on_the_study_sites_step
    expect(page).to have_content('Study sites')
  end

  def then_i_should_be_on_the_student_visa_step
    expect(page).to have_content('Can this course sponsor a student visa')
  end

  def then_i_should_be_on_the_skilled_worker_visa_step
    expect(page).to have_content('Can this course sponsor a skilled worker visa')
  end

  def then_i_should_be_on_the_visa_deadline_required_step
    expect(page).to have_content('Do you need to set a visa deadline')
  end

  def then_i_should_be_on_the_visa_deadline_at_step
    expect(page).to have_content('What is the visa deadline date')
  end

  def then_i_should_be_on_the_start_date_step
    expect(page).to have_content('Course start date')
  end

  def then_i_should_be_on_the_review_step
    expect(page).to have_content('Review your course')
  end

  def then_i_should_remain_on_the_level_step
    expect(page).to have_content('What type of course')
  end

  def then_i_should_remain_on_the_subject_step
    expect(page).to have_content('What subject')
  end

  def and_i_should_see_validation_error
    expect(page).to have_selector('.govuk-error-message')
  end

  def and_i_should_see_first_subject_validation_error
    expect(page).to have_text('Select a first subject')
  end

  def then_a_new_course_should_be_created
    expect(Course.count).to eq(1)
  end

  def then_the_first_subject_should_still_be_mathematics
    expect(page).to have_select('course[first_subject]', selected: 'Mathematics')
  end

  def and_the_second_subject_should_be_empty
    expect(page).to have_select('course[second_subject]', selected: '')
  end
end
