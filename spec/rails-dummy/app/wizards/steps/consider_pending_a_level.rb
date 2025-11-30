module Steps
  class ConsiderPendingALevel
    include DfE::Wizard::Step

    attribute :pending_a_level

    validates :pending_a_level, presence: true
  end
end
