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
end
