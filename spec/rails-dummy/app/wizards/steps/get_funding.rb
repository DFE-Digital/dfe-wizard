module Steps
  class GetFunding
    include DfE::Wizard::Step

    attr_accessor :funding_type, :amount_requested, :complete

    def self.permitted_params
      %w[
        funding_type
        amount_requested
        complete
      ]
    end
  end
end
