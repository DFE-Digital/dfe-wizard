module DfE
  module Wizard
    module Tooling
      # Documentation management for wizard flows
      #
      # Provides convenient access to wizard documentation generation capabilities.
      # Integrates with the Documentation::Generator to produce multi-format output
      # (markdown, mermaid, graphviz) from enriched wizard metadata.
      #
      # This mixin is automatically included in {DfE::Wizard}, making
      # documentation generation available on all wizard instances.
      #
      # @example Generate markdown documentation
      #   wizard = MyWizard.new(state_store: MyStateStore.new)
      #   wizard.documentation.generate(:markdown, 'docs/')
      #   # Creates: docs/my_wizard.md
      #
      # @example Generate all formats at once
      #   wizard.documentation.generate_all('docs/')
      #   # Creates: docs/mywizard.md, docs/my_wizard.mmd, docs/my_wizard.gv
      #
      # @example Customize documentation generation
      #   wizard.documentation(
      #     title: 'Custom Title',
      #     step_attributes: true,
      #     step_validations: false,
      #   ).generate_all('docs/')
      #
      # @api public
      # @since 3.0.0
      module DocManagement
        # Access documentation generator for this wizard
        #
        # Returns a generator instance configured with this wizard and optional settings.
        # The generator maintains a reference to the wizard, enabling dynamic documentation
        # based on current wizard state and configuration.
        #
        # Generators are created fresh on each call to allow customization per-call.
        # For repeated documentation generation, cache the result:
        #
        #   @doc_gen ||= wizard.documentation(custom_options)
        #
        # @param options [Hash] Configuration options for documentation generation
        # @option options [String] :title Custom documentation title (defaults to wizard class name)
        # @option options [Boolean] :step_attributes Include step attributes (default: true)
        # @option options [Boolean] :step_validations Include step validations (default: true)
        # @option options [Boolean] :step_operations Include step operations (default: true)
        # @option options [String] :generated_at Timestamp override (defaults to current time)
        # @option options [Boolean] :include_raw_metadata Include raw metadata dump (default: true)
        #
        # @return [DfE::Wizard::Documentation::Generator] Configured generator instance
        #
        # @raise [ArgumentError] If wizard lacks required interfaces
        #
        # @example Basic usage
        #   gen = wizard.documentation
        #   gen.generate(:markdown, 'output/')
        #
        # @example With customization
        #   gen = wizard.documentation(
        #     title: 'My Wizard Flow',
        #     theme: :semantic,
        #     step_attributes: false
        #   )
        #   output = gen.render(:markdown)
        #
        # @example Cache generator for repeated use
        #   @doc_gen = wizard.documentation(title: 'My Wizard')
        #   @doc_gen.generate_all('docs/')
        #
        # @api public
        def documentation(options = {})
          DfE::Wizard::Documentation::Generator.new(metadata, options)
        end

        def metadata
          DfE::Wizard::Metadata.new(self).to_h
        end
      end
    end
  end
end
