module Steps
  class ALevelEquivalencies
    include DfE::Wizard::Step

    MAXIMUM_ADDITIONAL_A_LEVEL_EQUIVALENCY_WORDS = 250

    attribute :accept_a_level_equivalency
    attribute :additional_a_level_equivalencies

    validates :accept_a_level_equivalency, presence: true
    validates :additional_a_level_equivalencies,
              words_count: { maximum: MAXIMUM_ADDITIONAL_A_LEVEL_EQUIVALENCY_WORDS },
              if: :accept_a_level_equivalency?,
              allow_blank: true

    def accept_a_level_equivalency?
      accept_a_level_equivalency == 'yes'
    end
  end
end
