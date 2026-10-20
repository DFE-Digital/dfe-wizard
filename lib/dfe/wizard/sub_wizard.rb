module DfE
  module Wizard
    # Class methods for a sub-wizard class (the class form of
    # `graph.add_sub_wizard`).
    #
    # A sub-wizard class draws its nodes and edges into the parent graph. It
    # reads context only through the state store, and lists the state store
    # methods it calls with `uses`. Every predicate it draws must be one of
    # them.
    #
    # @example
    #   class CourseWizard::VisaSubWizard
    #     extend DfE::Wizard::SubWizard
    #
    #     uses :visa_sponsorship_required?, :provider
    #
    #     def self.draw(graph)
    #       graph.add_node :visa_sponsorship, Steps::VisaSponsorship
    #       graph.add_multiple_conditional_edges(
    #         from: :visa_sponsorship,
    #         branches: [{ when: :visa_sponsorship_required?, then: :visa_sponsorship_application_deadline_required }],
    #       )
    #     end
    #   end
    #
    # @api public
    module SubWizard
      # Declare state store methods this sub-wizard calls, or list them.
      #
      # Each call adds to the list. With no arguments, returns the list.
      #
      # @param method_names [Array<Symbol>]
      # @return [Array<Symbol>] every declared method, in declaration order
      def uses(*method_names)
        @uses = (@uses || []) | method_names.map(&:to_sym)
        @uses.dup
      end
    end
  end
end
