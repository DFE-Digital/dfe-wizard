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

    # Handles params like { "date_of_birth(1i)"=>"1975", "date_of_birth(2i)"=>"11", "date_of_birth(3i)"=>"1" }
    def assign_attributes(attrs = {})
      super(attrs.except(
        'date_of_birth(1i)', 'date_of_birth(2i)', 'date_of_birth(3i)'
      ))
      if attrs['date_of_birth(1i)'].present? && attrs['date_of_birth(2i)'].present? && attrs['date_of_birth(3i)'].present?
        self.date_of_birth = begin
          Date.new(
            attrs['date_of_birth(1i)'].to_i,
            attrs['date_of_birth(2i)'].to_i,
            attrs['date_of_birth(3i)'].to_i,
          )
        rescue StandardError
          nil
        end
      end
    end
  end
end
