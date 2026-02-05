class RegisterECTReview
  include DfE::Wizard::CheckAnswersPresenter

  def teacher_details
    [
      row_for(:review_ect_details, :correct_full_name),
      row_for(:find_ect, :trn),
      row_for(:email_address, :email),
      row_for(:start_date, :start_date),
      row_for(:working_pattern, :working_pattern),
    ]
  end

  def programme_details
    [
      appropriate_body_row,
      row_for(:programme_type, :training_programme),
      row_for(:lead_provider, :lead_provider_id),
    ].compact
  end

  def format_value(attribute, value)
    case attribute
    when :start_date
      value&.to_fs(:govuk_date)
    when :working_pattern, :training_programme
      value&.humanize
    when :lead_provider_id
      lead_provider_name(value)
    else
      value
    end
  end

  private

  def appropriate_body_row
    step_id = state_store.school_independent? ? :independent_school_appropriate_body : :state_school_appropriate_body

    Row.new(
      step_id: step_id,
      attribute: :appropriate_body,
      step: nil,
      change_path: change_path_for(step_id),
      formatted_value: state_store.appropriate_body_text,
      custom_label: 'Appropriate body',
    )
  end

  def lead_provider_name(provider_id)
    providers = {
      'teach_first' => 'Teach First',
      'ambition' => 'Ambition Institute',
      'edt' => 'Education Development Trust',
    }
    providers[provider_id] || provider_id&.humanize
  end
end
