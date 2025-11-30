class Course < ApplicationRecord
  validates :course_code, presence: true
  validates :provider_code, presence: true
  validates :recruitment_cycle_year, presence: true

  # Ensure a_level_subject_requirements is always an array
  def a_level_subject_requirements
    super || []
  end

  # JSON structure for each A-level requirement:
  # {
  #   uuid: "generated-uuid",
  #   subject: "maths" | "physics" | "other_subject",
  #   minimum_grade_required: "A" | "B" | etc (optional),
  #   other_subject: "Custom Subject" (only if subject == "other_subject")
  # }
end
