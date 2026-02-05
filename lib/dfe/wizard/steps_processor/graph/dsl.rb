module DfE
  module Wizard
    module StepsProcessor
      class Graph < Base
        # DSL for building graph definitions.
        #
        # Provides fluent API for adding nodes, edges, and callbacks.
        # Converts user input (symbols, procs) into predicates stored in Registry.
        #
        # @api private
        class DSL
          def initialize(registry, wizard, predicate_caller:)
            @registry = registry
            @wizard = wizard
            @predicate_caller = predicate_caller
          end

          # Add a step node to the graph.
          #
          # @param node_id [Symbol] Unique node identifier
          # @param klass [Class] Step class to instantiate
          # @param label [String, nil] Display label for documentation
          #
          # @example
          #   g.add_node :personal_info, PersonalInfoStep
          #   g.add_node :confirmation, ConfirmationStep, label: "Review & Confirm"
          def add_node(node_id, klass, label: nil, skip_when: nil)
            raise ArgumentError, "node_id must be a symbol, got #{node_id.class}" unless node_id.is_a?(Symbol)
            raise ArgumentError, "klass must be a Class, got #{klass.class}" unless klass.is_a?(Class)

            @registry.add_node(node_id, klass, label:, skip_when:)
          end

          # Set static root node.
          #
          # @param node_id [Symbol]
          def root(node_id)
            if @registry.conditional_root_method || @registry.conditional_root_block
              raise ArgumentError,
                    'Cannot set both root and conditional_root'
            end

            @registry.root_node = node_id
          end

          # Set dynamic root node evaluated at runtime.
          #
          # @param method_name [Symbol, nil] Method to call on wizard for root
          # @yieldparam state_store [Object] Wizard's state store
          #
          # @example With method
          #   g.conditional_root :determine_entry_point
          #
          # @example With block
          #   g.conditional_root { |state| state.user_type == :student ? :student_path : :general_path }
          def conditional_root(method_name = nil, potential_root: nil, &block)
            if @registry.root_node || @registry.conditional_root_method || @registry.conditional_root_block
              raise ArgumentError, 'Cannot set both root and conditional_root'
            end

            if method_name && block_given?
              raise ArgumentError, 'Provide either method_name or block, not both'
            end

            unless method_name || block_given?
              raise ArgumentError, 'conditional_root requires method_name (symbol) or block'
            end

            if method_name
              unless @wizard.respond_to?(method_name, include_private: true)
                raise ArgumentError, "Method :#{method_name} not found on #{@wizard.class.name}"
              end

              @registry.conditional_root_method = method_name
            end

            unless potential_root.is_a?(Array) && potential_root.any?
              raise ArgumentError, <<~MESSAGE
                conditional_root requires :potential_root list of possible entry points for documentation.

                Example:

                  conditional_root(potential_root: [:login, :signup]) do |state|
                    state.new_user? ? :signup : :login
                  end

              MESSAGE
            end

            @registry.potential_root_nodes = potential_root
            @registry.conditional_root_block = block if block_given?
          end

          # Add unconditional linear edge.
          #
          # @param from [Symbol] Source node
          # @param to [Symbol] Target node
          #
          # @example
          #   g.add_edge from: :step1, to: :step2
          def add_edge(from:, to:)
            @registry.add_edge(from: from, to: to)
          end

          # Add binary conditional edge (if/else).
          #
          # Routes to one of two steps based on a predicate.
          # Use this for yes/no decisions.
          #
          # @param from [Symbol] Source node
          # @param when [Symbol, Proc] Predicate (method name or proc)
          # @param then [Symbol] Target if predicate true
          # @param else [Symbol] Target if predicate false
          # @param label [String, nil] For documentation
          #
          # @example With method predicate
          #   g.add_conditional_edge from: :visa_check, when: :eligible?, then: :eligible_path, else: :ineligible_path
          #
          # @example With proc predicate
          #   g.add_conditional_edge from: :age_check, when: ->(step) { step.age >= 18 }, then: :adult, else: :minor
          def add_conditional_edge(from:, **kwargs)
            then_step = kwargs[:then]
            else_step = kwargs[:else]
            label = kwargs[:label]
            predicate = build_predicate(kwargs[:when])

            @registry.add_conditional_edge(
              from:,
              when_original: kwargs[:when],
              when_predicate: predicate,
              then_step:,
              else_step:,
              label:,
            )
          end

          # Add N-way conditional edge (multiple branches).
          #
          # Routes to one of many steps based on ordered conditions.
          # First matching condition wins. Always place specific conditions first.
          #
          # @param from [Symbol] Source node
          # @param branches [Array<Hash>] Array of { when:, then:, label: }
          # @param default [Symbol, nil] Fallback if no branch matches
          # @param label [String, nil] Overall edge label for docs
          #
          # @example Visa type routing
          #   g.add_multiple_conditional_edges(
          #     from: :visa_type,
          #     branches: [
          #       { when: :student_visa?, then: :student_details },
          #       { when: :work_visa?, then: :work_details },
          #       { when: :family_visa?, then: :family_details }
          #     ],
          #     default: :other_visa
          #   )
          #
          # @example With proc predicates
          #   g.add_multiple_conditional_edges(
          #     from: :age_group,
          #     branches: [
          #       { when: ->(s) { s.age < 18 }, then: :minor_path, label: "Under 18" },
          #       { when: ->(s) { s.age >= 65 }, then: :senior_path, label: "65+" },
          #       { when: ->(s) { s.age >= 18 }, then: :adult_path, label: "18-64" }
          #     ]
          #   )
          def add_multiple_conditional_edges(from:, branches:, default: nil, label: nil)
            unless @registry.nodes.key?(from)
              raise ArgumentError, "Source node :#{from} not found. Add it with add_node first."
            end

            raise ArgumentError, 'branches cannot be empty' if branches.nil? || branches.empty?

            processed_branches = branches.map.with_index do |branch, index|
              raise ArgumentError, "Branch #{index} must be a Hash" unless branch.is_a?(Hash)
              raise ArgumentError, "Branch #{index} missing :when key" unless branch.key?(:when)
              raise ArgumentError, "Branch #{index} missing :then key" unless branch.key?(:then)

              unless @registry.nodes.key?(branch[:then])
                raise ArgumentError, "Branch #{index} target :#{branch[:then]} not found"
              end

              {
                when: build_predicate(branch[:when]),
                when_original: branch[:when],
                then: branch[:then],
                label: branch[:label],
              }
            end

            @registry.add_multiple_conditional_edge(
              from: from,
              branches: processed_branches,
              default: default,
              label: label,
            )
          end

          # ====================================================================
          # CUSTOM BRANCHING
          # ====================================================================

          # Add custom branching edge for arbitrary logic.
          #
          # Use this for complex transitions that don't fit the other patterns.
          # The conditional should return the target step ID directly (not true/false).
          #
          # When using a Symbol, the method is called on the predicate_caller
          # (typically state_store), consistent with other edge types.
          #
          # @param from [Symbol] Source node
          # @param conditional [Symbol, Proc] Logic returning target step ID
          # @param potential_transitions [Array<Hash>] Documentation of possible paths
          #
          # @example With a method on state_store
          #   # In state_store:
          #   def determine_payment_path
          #     case payment_status
          #     when 'approved' then :confirmation
          #     when 'pending' then :payment_pending
          #     else :retry_payment
          #     end
          #   end
          #
          #   # In graph definition:
          #   g.add_custom_branching_edge(
          #     from: :payment,
          #     conditional: :determine_payment_path,
          #     potential_transitions: [
          #       { label: "Payment approved", nodes: [:confirmation] },
          #       { label: "Payment pending", nodes: [:payment_pending] },
          #       { label: "Payment failed", nodes: [:retry_payment] }
          #     ]
          #   )
          #
          # @example With a proc
          #   g.add_custom_branching_edge(
          #     from: :payment,
          #     conditional: proc { |step| step.payment_status == 'approved' ? :confirmation : :retry },
          #     potential_transitions: [...]
          #   )
          def add_custom_branching_edge(from:, conditional:, potential_transitions:)
            predicate = build_predicate(conditional)

            @registry.add_custom_branching_edge(
              from: from,
              conditional: predicate,
              potential_transitions: potential_transitions,
            )
          end

          # Register callback before navigating to next step.
          #
          # Block is called with no arguments. Returning a step ID overrides
          # normal navigation. Returning nil continues normal navigation.
          #
          # @param method [Symbol, nil] Method to call on wizard
          # @yieldparam [nil] Block executed before next_step
          #
          # @example With method
          #   g.before_next_step :validate_current_step
          #
          # @example With block
          #   g.before_next_step do
          #     return :error if validation_failed?
          #     nil
          #   end
          def before_next_step(method = nil, &block)
            callback = if block_given?
                         block
                       else
                         @wizard.method(method)
                       end

            @registry.add_before_next_callback(callback)
          end

          # Register callback before navigating to previous step.
          #
          # @param method [Symbol, nil] Method to call on wizard
          # @yieldparam [nil] Block executed before previous_step
          #
          # @example With method
          #   g.before_previous_step :confirm_can_go_back
          #
          # @example With block
          #   g.before_previous_step do
          #     return nil if can_go_back?
          #   end
          def before_previous_step(method = nil, &block)
            callback = if block_given?
                         block
                       else
                         @wizard.method(method)
                       end

            @registry.add_before_previous_callback(callback)
          end

          private

          # Build a predicate callable.
          #
          # @param raw [Symbol, Proc] Method name or callable
          # @param caller [Object] Object to call the method on (defaults to predicate_caller)
          def build_predicate(raw, caller: @predicate_caller)
            if raw.is_a?(Symbol)
              unless caller.respond_to?(raw, include_private: true)
                raise ArgumentError, "Predicate method :#{raw} not found on #{caller.class.name}"
              end

              bound_method = caller.method(raw)

              if bound_method.arity.zero? || bound_method.arity.negative?
                proc { bound_method.call }
              else
                proc { |step| bound_method.call(step) }
              end

            elsif raw.respond_to?(:call)
              raw

            else
              raise ArgumentError, "Predicate must be Symbol or Proc, got #{raw.class}"
            end
          end
        end
      end
    end
  end
end
