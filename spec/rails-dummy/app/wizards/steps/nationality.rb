module Steps
  class Nationality
    include DfE::Wizard::Step

    attribute :nationalities, default: []
    attribute :other_nationality, :string

    validate :at_least_one_nationality

    def at_least_one_nationality
      if nationalities.blank? || nationalities.reject(&:blank?).empty?
        errors.add(:nationalities, :blank)
      end
    end

    def nationalities=(list)
      super(Array(list).reject(&:blank?))
    end

    def self.permitted_params
      [
        { nationalities: [] },
        :other_nationality,
      ]
    end
  end
end
