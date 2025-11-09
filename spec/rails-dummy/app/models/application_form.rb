class ApplicationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :integer, default: -> { SecureRandom.uuid }
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :date_of_birth, :date
  attribute :nationality, :string
  attribute :other_nationality, :string
  attribute :right_to_work, :string
  attribute :visa_type, :string
  attribute :visa_expiry, :date
  attribute :immigration_status, :string
  attribute :other_status, :string
  attribute :wizard_state, :string, default: '{}'

  validates :first_name, :last_name, :date_of_birth, presence: true

  attribute :highest_qualification, :string
  attribute :institution_name, :string
  attribute :needs_funding, :boolean
  attribute :funding_type, :string
  attribute :amount_requested, :float
  attribute :funding_section_complete, :boolean
  attribute :has_visa, :boolean
  attribute :needs_support, :boolean
  attribute :requires_accessibility, :boolean
  attribute :support_notes, :boolean

  alias nationalities nationality
  alias nationalities= nationality=
  alias other_nationalities= other_nationality=
  alias other_nationalities other_nationality
  alias right_to_work_or_study= right_to_work=
  alias right_to_work_or_study right_to_work

  alias status immigration_status
  alias other_status= immigration_status=
  alias status= immigration_status=

  def update!(attrs)
    assign_attributes(attrs)
    self
  end
end
