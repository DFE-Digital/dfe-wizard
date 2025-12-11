module Repositories
  class ALevelsRequirements < DfE::Wizard::Repository::Model
    def transform_for_write(data)
      data[:accept_pending_a_level] = data[:pending_a_level] unless data[:pending_a_level].nil?

      data
    end
  end
end
