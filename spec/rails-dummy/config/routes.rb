Rails.application.routes.draw do
  root to: 'home#index'

  resources :wizards, only: %i[index]

  # Personal Information Wizard
  namespace :personal_information, path: 'personal-information' do
    get '/name-and-date-of-birth', to: 'name_and_date_of_birth#new', as: :name_and_date_of_birth
    post '/name-and-date-of-birth', to: 'name_and_date_of_birth#create'
    get '/nationality', to: 'nationality#new', as: :nationality
    post '/nationality', to: 'nationality#create'
    get '/right-to-work-or-study', to: 'right_to_work_or_study#new', as: :right_to_work_or_study
    post '/right-to-work-or-study', to: 'right_to_work_or_study#create'
    get '/immigration-status', to: 'immigration_status#new', as: :immigration_status
    post '/immigration-status', to: 'immigration_status#create'
    get '/review', to: 'review#index', as: :review
  end

  # Assign Mentor Wizard
  namespace :assign_mentor, path: 'assign-mentor' do
    get  '/who-will-be-the-mentor', to: 'who_will_be_the_mentor#new', as: :who_will_be_the_mentor
    post '/who-will-be-the-mentor', to: 'who_will_be_the_mentor#create'

    get  '/can-receive-mentor-training', to: 'can_receive_mentor_training#new', as: :can_receive_mentor_training
    post '/can-receive-mentor-training', to: 'can_receive_mentor_training#create'

    get  '/which-lead-provider', to: 'which_lead_provider#new', as: :which_lead_provider
    post '/which-lead-provider', to: 'which_lead_provider#create'

    get  '/confirmation', to: 'confirmation#new', as: :confirmation
    post '/confirmation', to: 'confirmation#create'
  end

  # Register ECT Wizard
  namespace :register_ect, path: 'register-ect' do
    get  '/find-ect', to: 'find_ect#new', as: :find_ect
    post '/find-ect', to: 'find_ect#create'

    get  '/trn-not-found', to: 'trn_not_found#new', as: :trn_not_found
    post '/trn-not-found', to: 'trn_not_found#create'

    get  '/national-insurance-number', to: 'national_insurance_number#new', as: :national_insurance_number
    post '/national-insurance-number', to: 'national_insurance_number#create'

    get  '/already-active-at-school', to: 'already_active_at_school#new', as: :already_active_at_school
    post '/already-active-at-school', to: 'already_active_at_school#create'

    get  '/induction-completed', to: 'induction_completed#new', as: :induction_completed
    post '/induction-completed', to: 'induction_completed#create'

    get  '/induction-exempt', to: 'induction_exempt#new', as: :induction_exempt
    post '/induction-exempt', to: 'induction_exempt#create'

    get  '/cannot-register-ect', to: 'cannot_register_ect#new', as: :cannot_register_ect
    post '/cannot-register-ect', to: 'cannot_register_ect#create'

    get  '/review-ect-details', to: 'review_ect_details#new', as: :review_ect_details
    post '/review-ect-details', to: 'review_ect_details#create'

    get  '/email-address', to: 'email_address#new', as: :email_address
    post '/email-address', to: 'email_address#create'

    get  '/cant-use-email', to: 'cant_use_email#new', as: :cant_use_email
    post '/cant-use-email', to: 'cant_use_email#create'

    get  '/start-date', to: 'start_date#new', as: :start_date
    post '/start-date', to: 'start_date#create'

    get  '/working-pattern', to: 'working_pattern#new', as: :working_pattern
    post '/working-pattern', to: 'working_pattern#create'

    get  '/independent-school-appropriate-body', to: 'independent_school_appropriate_body#new', as: :independent_school_appropriate_body
    post '/independent-school-appropriate-body', to: 'independent_school_appropriate_body#create'

    get  '/state-school-appropriate-body', to: 'state_school_appropriate_body#new', as: :state_school_appropriate_body
    post '/state-school-appropriate-body', to: 'state_school_appropriate_body#create'

    get  '/programme-type', to: 'programme_type#new', as: :programme_type
    post '/programme-type', to: 'programme_type#create'

    get  '/lead-provider', to: 'lead_provider#new', as: :lead_provider
    post '/lead-provider', to: 'lead_provider#create'

    get  '/check-answers', to: 'check_answers#new', as: :check_answers
    post '/check-answers', to: 'check_answers#create'

    get  '/not-found', to: 'not_found#new', as: :not_found
    post '/not-found', to: 'not_found#create'

    get  '/confirmation', to: 'confirmation#new', as: :confirmation
    post '/confirmation', to: 'confirmation#create'
  end
end
