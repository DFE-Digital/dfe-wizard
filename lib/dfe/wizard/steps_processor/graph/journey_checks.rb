module DfE
  module Wizard
    module StepsProcessor
      class Graph < Base
        # Draw-time checks for change journeys.
        #
        # Run at the end of every draw, after the sub-wizard checks:
        # - no step attribute is named `_dfe_wizard` (every graph);
        # - the check answers node is a node, in no sub-wizard, with no
        #   depends_on (rule 3);
        # - the edit review node is a node, in no sub-wizard, with no
        #   depends_on, and not the check answers node, in a graph that
        #   declares graph.check_answers;
        # - every depends_on name is a step attribute, and a node in a
        #   sub-wizard declares none of its own.
        #
        # @api private
        class JourneyChecks
          # @param graph [Graph]
          def initialize(graph)
            @registry = graph.registry
            @answer_owners = graph.answer_owners
          end

          # @raise [DfE::Wizard::InvalidGraph]
          # @return [void]
          def run!
            check_reserved_attribute!
            check_check_answers_node!
            check_edit_review_node!
            check_depends_on!
          end

          private

          def check_reserved_attribute!
            owner = @answer_owners[Changeset::KEY]
            return unless owner

            raise InvalidGraph,
                  "step attribute #{Changeset::KEY} on :#{owner} is reserved by dfe-wizard; rename it"
          end

          def check_check_answers_node!
            node_id = @registry.check_answers_node
            return unless node_id

            node = check_marked_node!(node_id, directive: 'graph.check_answers')
            check_unitless_node!(node, noun: 'check answers node')
          end

          def check_edit_review_node!
            node_id = @registry.edit_review_node
            return unless node_id

            node = check_marked_node!(node_id, directive: 'graph.edit_review')
            raise InvalidGraph, 'graph.edit_review needs graph.check_answers' unless @registry.check_answers_node
            if node_id == @registry.check_answers_node
              raise InvalidGraph, ":#{node_id} cannot be both the check answers node and the edit review node"
            end

            check_unitless_node!(node, noun: 'edit review node')
          end

          # @return [Registry::Node]
          def check_marked_node!(node_id, directive:)
            @registry.nodes[node_id] || raise(InvalidGraph, "#{directive} :#{node_id} is not a node")
          end

          def check_unitless_node!(node, noun:)
            owner = @registry.sub_wizard_for(node.id)
            if owner
              raise InvalidGraph, "the #{noun} :#{node.id} is in sub-wizard :#{owner.id}; it belongs to no unit"
            end
            return if node.depends_on.empty?

            raise InvalidGraph, "the #{noun} :#{node.id} cannot have depends_on"
          end

          def check_depends_on!
            @registry.nodes.each_value do |node|
              next if node.depends_on.empty?
              next unless @registry.sub_wizard_for(node.id)

              raise InvalidGraph, ":#{node.id} is in a sub-wizard; declare depends_on on add_sub_wizard"
            end

            owners = @registry.nodes.values.map { |node| [":#{node.id}", node.depends_on] } +
                     @registry.sub_wizards.values.map { |unit| ["sub-wizard :#{unit.id}", unit.depends_on] }
            owners.each do |owner, names|
              unknown = names - @answer_owners.keys
              next if unknown.empty?

              raise InvalidGraph,
                    "#{owner}: depends_on #{unknown.map(&:inspect).join(', ')} is not a step attribute"
            end
          end
        end
      end
    end
  end
end
