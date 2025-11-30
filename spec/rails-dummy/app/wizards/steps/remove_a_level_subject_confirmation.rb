module Steps
  class RemoveALevelSubjectConfirmation
    include DfE::Wizard::Step

    attribute :uuid
    attribute :subject
    attribute :other_subject
    attribute :confirmation

    validates :uuid, presence: true
    validate :validate_confirmation

    def subject_name
      subject == 'other_subject' ? other_subject : subject
    end

    def deletion_confirmed?
      confirmation == 'yes'
    end

    private

    def validate_confirmation
      errors.add(:confirmation, :blank, subject: subject_name) if confirmation.blank?
    end
  end
end
