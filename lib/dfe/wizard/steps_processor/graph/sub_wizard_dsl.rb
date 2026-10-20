module DfE
  module Wizard
    module StepsProcessor
      class Graph < Base
        # The graph a sub-wizard class draws into.
        #
        # Passes nodes and edges to the parent DSL, with three limits:
        # - every predicate is a Symbol listed in the class's `uses` (rule 7);
        # - edges start only at nodes the class added, and a node id must be
        #   new (rules 3 and 5);
        # - root, callbacks and nested sub-wizards raise (rule 5).
        #
        # @api private
        class SubWizardDSL
          PARENT_ONLY = %i[root conditional_root before_next_step before_previous_step check_answers].freeze

          # @return [Array<Symbol>] node ids the class added, in order
          attr_reader :added_node_ids

          # @param dsl [DSL] The parent graph's DSL
          # @param registry [Registry] The parent graph's registry
          # @param name [String] The sub-wizard, for messages
          # @param uses [Array<Symbol>] State store methods the class declared
          def initialize(dsl, registry, name:, uses:)
            @dsl = dsl
            @registry = registry
            @name = name
            @uses = uses
            @added_node_ids = []
          end

          def add_node(node_id, klass, label: nil, skip_when: nil, depends_on: nil)
            raise InvalidGraph, "#{@name} adds :#{node_id}, which is already a node" if @registry.nodes.key?(node_id)
            unless depends_on.nil?
              raise InvalidGraph, "#{@name}: depends_on on :#{node_id}; declare depends_on on add_sub_wizard"
            end

            check_predicate!(skip_when, "skip_when on :#{node_id}") unless skip_when.nil?
            @dsl.add_node(node_id, klass, label:, skip_when:)
            @added_node_ids << node_id
          end

          def add_edge(from:, to:)
            check_from!(from)
            @dsl.add_edge(from:, to:)
          end

          def add_conditional_edge(from:, **kwargs)
            check_from!(from)
            check_predicate!(kwargs[:when], "the edge from :#{from}")
            @dsl.add_conditional_edge(from:, **kwargs)
          end

          def add_multiple_conditional_edges(from:, branches:, default: nil, label: nil)
            check_from!(from)
            Array(branches).each do |branch|
              check_predicate!(branch[:when], "a branch from :#{from}") if branch.is_a?(Hash) && branch.key?(:when)
            end
            @dsl.add_multiple_conditional_edges(from:, branches:, default:, label:)
          end

          def add_custom_branching_edge(from:, conditional:, potential_transitions:)
            check_from!(from)
            check_predicate!(conditional, "the custom edge from :#{from}")
            @dsl.add_custom_branching_edge(from:, conditional:, potential_transitions:)
          end

          def add_sub_wizard(*, **)
            raise InvalidGraph, "#{@name} declares a sub-wizard; sub-wizards are one level only"
          end

          PARENT_ONLY.each do |method_name|
            define_method(method_name) do |*_args, **_kwargs, &_block|
              raise InvalidGraph, "#{@name} calls #{method_name}; a sub-wizard adds nodes and edges only"
            end
          end

          private

          def check_from!(from)
            return if @added_node_ids.include?(from)

            raise InvalidGraph, "#{@name} adds an edge from :#{from}, which it did not add"
          end

          def check_predicate!(predicate, where)
            unless predicate.is_a?(Symbol)
              raise InvalidGraph,
                    "#{@name}: #{where} uses a #{predicate.class}; " \
                    'a sub-wizard predicate must be a Symbol listed in uses'
            end
            return if @uses.include?(predicate)

            raise InvalidGraph, "#{@name}: #{where} uses :#{predicate}, which is not listed in uses"
          end
        end
      end
    end
  end
end
