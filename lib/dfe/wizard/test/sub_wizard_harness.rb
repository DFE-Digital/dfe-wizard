module DfE
  module Wizard
    module Test
      # Runs one sub-wizard class on its own, for its specs.
      #
      # Builds a small wizard: the class drawn as sub-wizard :sub_wizard,
      # with exit_to: :sub_wizard_exit, an exit node, and the given root.
      # The wizard has only the gem's methods, so a step that calls an app
      # wizard method raises NoMethodError (sub-wizards read context only
      # through the state store).
      #
      # With no state_store:, the harness builds a stub store from the
      # class's `uses`: each method returns its value in `stubs:` (a callable
      # is called with the store), and raises when it has no stub.
      #
      # @example With the app's store
      #   harness = DfE::Wizard::Test::SubWizardHarness.new(
      #     CourseWizard::VisaSubWizard,
      #     root: :visa_sponsorship,
      #     state_store: CourseWizard::StateStores::CourseWizardStore.new,
      #   )
      #   expect(harness.wizard).to have_next_step(:sub_wizard_exit)
      #     .from(:visa_sponsorship).when(can_sponsor_student_visa: false)
      #
      # @example With stubs
      #   harness = DfE::Wizard::Test::SubWizardHarness.new(
      #     CourseWizard::VisaSubWizard,
      #     root: :visa_sponsorship,
      #     stubs: { visa_sponsorship_required?: true },
      #   )
      #
      # @api public
      class SubWizardHarness
        UNIT_ID = :sub_wizard
        EXIT_ID = :sub_wizard_exit

        # The node the sub-wizard exits to.
        class ExitStep
          include DfE::Wizard::Step
        end

        # @return [DfE::Wizard] the harness wizard
        attr_reader :wizard

        # @param sub_wizard [#draw] The sub-wizard class
        # @param root [Symbol] The step to start at
        # @param state_store [DfE::Wizard::StateStore, nil] A real store; a stub store when nil
        # @param stubs [Hash{Symbol => Object}] Stub store values, by method name
        # @param current_step [Symbol, nil]
        # @raise [ArgumentError] When stubs name a method that is not in uses
        def initialize(sub_wizard, root:, state_store: nil, stubs: {}, current_step: nil)
          store = state_store || build_stub_store(sub_wizard, stubs.transform_keys(&:to_sym))
          @wizard = build_wizard_class(sub_wizard, root).new(state_store: store, current_step:)
        end

        private

        def build_wizard_class(sub_wizard, root)
          Class.new do
            include DfE::Wizard

            define_method(:steps_processor) do
              DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
                graph.add_sub_wizard UNIT_ID, sub_wizard, exit_to: EXIT_ID
                graph.add_node EXIT_ID, ExitStep
                graph.root root
              end
            end

            def logger
              nil
            end

            def route_strategy
              nil
            end
          end
        end

        def build_stub_store(sub_wizard, stubs)
          uses = sub_wizard.respond_to?(:uses) ? Array(sub_wizard.uses).map(&:to_sym) : []
          unknown = stubs.keys - uses
          raise ArgumentError, "stubs for methods not in uses: #{unknown.map(&:inspect).join(', ')}" if unknown.any?

          store_class = Class.new { include DfE::Wizard::StateStore }
          uses.each do |method_name|
            store_class.define_method(method_name) do |*_args|
              unless stubs.key?(method_name)
                raise NotImplementedError, "no stub for :#{method_name}; pass stubs: { #{method_name}: ... }"
              end

              value = stubs[method_name]
              value.respond_to?(:call) ? value.call(self) : value
            end
          end
          store_class.new
        end
      end
    end
  end
end
