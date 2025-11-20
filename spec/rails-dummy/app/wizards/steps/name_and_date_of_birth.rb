module Steps
  class NameAndDateOfBirth
    include DfE::Wizard::Step

    attribute :first_name, :string
    attribute :last_name, :string
    attribute :date_of_birth, :date

    validates :first_name, :last_name, :date_of_birth, presence: true

    def self.permitted_params
      %w[
        first_name
        last_name
        date_of_birth
      ]
    end

    # Handles params like
    # { "date_of_birth(1i)"=>"1975", "date_of_birth(2i)"=>"11", "date_of_birth(3i)"=>"1" }
    def assign_attributes(attrs = {})
      # Extract date parts before passing to super
      date_parts = attrs.symbolize_keys!.extract!(:'date_of_birth(1i)', :'date_of_birth(2i)', :'date_of_birth(3i)')

      # Assign remaining attributes normally
      super

      # Handle multi-parameter date input
      if date_parts[:'date_of_birth(1i)'].present? &&
         date_parts[:'date_of_birth(2i)'].present? &&
         date_parts[:'date_of_birth(3i)'].present?
        self.date_of_birth = Date.new(
          date_parts[:'date_of_birth(1i)'].to_i,
          date_parts[:'date_of_birth(2i)'].to_i,
          date_parts[:'date_of_birth(3i)'].to_i,
        )
      end
    end
  end
end
