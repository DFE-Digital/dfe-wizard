module DfE
  module Wizard
    # The mapper role: seeds an edit of a saved record.
    #
    # A wizard that edits saved records returns a mapper from `#mapper`.
    # The gem calls `to_answers` once, in `start_edit`. The commit
    # operation maps `changeset.diff` back to the record itself.
    #
    # Seed only the answers on the record's own branch. A step that a
    # change brings onto the path then starts blank, and its validation
    # asks the user for it. Test each mapper: `to_answers` must give
    # answers the steps accept.
    #
    # @example
    #   class CourseWizard::Mapper
    #     include DfE::Wizard::Mapper
    #
    #     def to_answers(course)
    #       { funding_type: course.funding, ... }
    #     end
    #   end
    #
    # @api public
    module Mapper
      # The answers for a saved record, in step attribute names
      #
      # @param record [Object]
      # @return [Hash{Symbol => Object}]
      def to_answers(record)
        raise NotImplementedError, "#{self.class}#to_answers not implemented"
      end
    end
  end
end
