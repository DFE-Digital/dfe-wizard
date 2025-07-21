Rails.application.routes.draw do
  root to: 'home#index'

  resources :wizards, only: %i[index]

  # Personal Information Wizard
  namespace :personal_information, path: 'personal-information' do
    get '/name-and-date-of-birth', to: 'name_and_date_of_birth#new', as: :name_and_date_of_birth
    post '/name-and-date-of-birth', to: 'name_and_date_of_birth#create'
    get '/nationality', to: 'nationality#new', as: :nationality
    get '/right-to-work-or-study', to: 'right_to_work_or_study#new', as: :right_to_work_or_study
    get '/immigration-status', to: 'immigration_status#new', as: :immigration_status
    get '/review', to: 'review#index', as: :review
  end

  # Get Funding Wizard
  namespace :get_funding, path: 'get-funding' do
    get '/personal-details', to: 'personal_details#new', as: :personal_details
  end
end
