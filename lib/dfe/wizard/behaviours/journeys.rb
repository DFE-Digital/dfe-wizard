module DfE
  module Wizard
    module Behaviours
      # Change journeys from check answers.
      #
      # Turned on by `graph.check_answers` in a Graph wizard. A wizard that
      # does not declare it behaves as in 1.0.
      #
      # @api public
      module Journeys
        # The wizard's changeset
        #
        # Memoised per wizard instance. Building it reads and writes nothing.
        #
        # @return [DfE::Wizard::Changeset]
        def changeset
          @changeset ||= Changeset.new(self)
        end
      end
    end
  end
end
