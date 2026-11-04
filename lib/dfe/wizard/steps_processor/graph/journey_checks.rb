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

            node = @registry.nodes[node_id]
            raise InvalidGraph, "graph.check_answers :#{node_id} is not a node" unless node

            owner = @registry.sub_wizard_for(node_id)
            if owner
              raise InvalidGraph,
                    "the check answers node :#{node_id} is in sub-wizard :#{owner.id}; it belongs to no unit"
            end
            return if node.depends_on.empty?

            raise InvalidGraph, "the check answers node :#{node_id} cannot have depends_on"
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
