class NationalityStep < DfE::Wizard::Step
  attr_accessor :nationalities, :other_nationalities

  def self.permitted_params
    %w[
      nationalities
      other_nationalities
    ]
  end
end
