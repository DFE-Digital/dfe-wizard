module DfE
  module Wizard
    module Core
      # Virtual step for redirecting outside the wizard
      #
      # Used as an exit point to redirect to another page after wizard completion.
      # Does not collect or validate data.
      #
      # @example
      #   graph.add_node :course_edit, DfE::Wizard::Steps::Redirect
      class Redirect
        include DfE::Wizard::Step

        # Redirects always pass validation (no data to validate)
        def valid?
          true
        end

        # No attributes to validate
        def attributes
          {}
        end
      end
    end
  end
end
