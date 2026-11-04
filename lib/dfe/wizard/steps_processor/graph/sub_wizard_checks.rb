module DfE
  module Wizard
    module StepsProcessor
      class Graph < Base
        # Draw-time checks for sub-wizards (rules 1 to 4).
        #
        # Run at the end of every draw, after exits are wired. A graph with
        # no sub-wizards skips them. The checks use static targets only:
        # edge targets, then/else, branch targets, defaults and a custom
        # edge's potential_transitions (best effort; those are for docs).
        # Callbacks are not followed.
        #
        # @api private
        class SubWizardChecks
          # @param registry [Registry]
          def initialize(registry)
            @registry = registry
          end

          # @raise [DfE::Wizard::InvalidGraph]
          # @return [void]
          def run!
            units = @registry.sub_wizards.values
            return if units.empty?

            units.each { |unit| check_ids!(unit) }
            check_one_sub_wizard_per_step!(units)
            units.each do |unit|
              check_one_exit_target!(unit)
              check_contiguous!(unit)
            end
          end

          private

          # Rule 4
          def check_ids!(unit)
            if @registry.nodes.key?(unit.id)
              raise InvalidGraph, "sub-wizard id :#{unit.id} is also a node id; choose another id"
            end

            missing = unit.step_ids.reject { |step_id| @registry.nodes.key?(step_id) }
            return if missing.empty?

            verb = missing.one? ? 'is not a node' : 'are not nodes'
            raise InvalidGraph, "sub-wizard :#{unit.id} lists #{list(missing)}, which #{verb}"
          end

          # Rule 3 (JourneyChecks keeps the check answers node out of every
          # sub-wizard)
          def check_one_sub_wizard_per_step!(units)
            owners = Hash.new { |hash, step_id| hash[step_id] = [] }
            units.each { |unit| unit.step_ids.each { |step_id| owners[step_id] << unit.id } }
            step_id, unit_ids = owners.find { |_, ids| ids.size > 1 }
            return unless step_id

            raise InvalidGraph, ":#{step_id} is in more than one sub-wizard (#{list(unit_ids)})"
          end

          # Rule 2
          def check_one_exit_target!(unit)
            exits = exit_targets(unit)
            return if exits.size <= 1

            raise InvalidGraph,
                  "sub-wizard :#{unit.id} exits to #{list(exits)}; a sub-wizard has one exit target (see exit_to:)"
          end

          # Rule 1: walk from the exits; reaching a unit step again fails.
          def check_contiguous!(unit)
            queue = exit_targets(unit)
            seen = Set.new

            until queue.empty?
              node_id = queue.shift
              next unless seen.add?(node_id)

              targets[node_id].each do |target|
                if unit.step_ids.include?(target)
                  raise InvalidGraph,
                        "sub-wizard :#{unit.id} is not contiguous: " \
                        "a path leaves it, reaches :#{node_id} and comes back to :#{target}"
                end

                queue << target
              end
            end
          end

          # Targets outside the unit, in step order then edge order.
          def exit_targets(unit)
            unit.step_ids.flat_map { |step_id| targets[step_id] }.uniq - unit.step_ids
          end

          # Static targets of every node, built once per run.
          def targets
            @targets ||= build_targets
          end

          def build_targets
            map = Hash.new { |hash, node_id| hash[node_id] = [] }
            @registry.edges.each { |edge| map[edge.from] << edge.to }
            @registry.conditional_edges.each { |edge| map[edge.from].push(edge.then, edge.else) }
            @registry.multiple_conditional_edges.each do |edge|
              map[edge.from].concat(edge.branches.map { |branch| branch[:then] }).push(edge.default)
            end
            @registry.custom_branching_edges.each do |edge|
              Array(edge.potential_transitions).each do |transition|
                map[edge.from].concat(Array(transition[:nodes]))
              end
            end
            map.each_value do |ids|
              ids.compact!
              ids.uniq!
            end
            map
          end

          def list(ids)
            ids.map(&:inspect).join(', ')
          end
        end
      end
    end
  end
end
