class ApplicationController < ActionController::Base
  layout 'application'
  default_form_builder GOVUKDesignSystemFormBuilder::FormBuilder
end
