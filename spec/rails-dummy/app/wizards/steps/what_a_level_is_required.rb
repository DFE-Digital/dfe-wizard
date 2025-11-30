module Steps
  class WhatALevelIsRequired
    include DfE::Wizard::Step

    MAXIMUM_GRADE_CHARACTERS = 50

    attribute :uuid
    attribute :subject
    attribute :other_subject
    attribute :minimum_grade_required

    validates :subject, presence: true
    validates :other_subject, presence: true, if: -> { subject == 'other_subject' }
    validates :minimum_grade_required,
              length: { maximum: MAXIMUM_GRADE_CHARACTERS },
              allow_blank: true

    def initialize(step_attributes = {})
      super
      @uuid ||= SecureRandom.uuid
    end

    def subjects_list
      A_AND_AS_LEVEL_SUBJECTS.map { |name| OpenStruct.new(name:) }
    end
  end
end
