module DfE
  module Wizard
    module Core
      # Documentation generation for wizard flows
      #
      # Provides methods to generate visual documentation of wizard steps,
      # transitions, and branching logic using GraphViz.
      #
      # @api public
      module Documentation
        # Generate GraphViz documentation for this wizard
        #
        # Creates a visual representation of the wizard flow including:
        # - All steps and their sequence
        # - Conditional branching (if/else paths)
        # - Complex multi-option branching
        # - Entry and exit points
        #
        # The theme and title can be customized either by passing parameters
        # or by overriding `documentation_theme` and `documentation_title`.
        #
        # @param theme [Symbol] Visual theme: :minimal, :detailed, :semantic
        # @param title [String, nil] Custom graph title (overrides documentation_title)
        # @return [GraphViz] GraphViz object ready to render
        #
        # @example Generate SVG documentation
        #   wizard.to_doc(:semantic).output(svg: 'wizard_flow.svg')
        #
        # @example Generate PNG with custom title
        #   wizard.to_doc(:detailed, title: 'Custom Flow').output(png: 'flow.png')
        #
        # @example Use wizard's default theme and title
        #   wizard.to_doc.output(svg: 'flow.svg')
        #
        # @api public
        def to_doc(theme: nil, title: nil)
          steps_processor.to_doc(
            theme: theme || documentation_theme,
            title: title || documentation_title,
          )
        end

        # Default documentation title for this wizard
        #
        # Override this method in your wizard class to provide a custom title
        # that appears in the generated documentation. The title should be
        # descriptive of the wizard's purpose.
        #
        # @return [String] The documentation title
        #
        # @example Simple title
        #   def documentation_title
        #     "Personal Information Collection"
        #   end
        #
        # @example Dynamic title
        #   def documentation_title
        #     "Claim Submission Flow - #{fiscal_year}"
        #   end
        #
        # @example Multi-language support
        #   def documentation_title
        #     I18n.t('wizards.personal_info.title')
        #   end
        #
        # @api public
        def documentation_title
          self.class.name
        end

        # Default documentation theme for this wizard
        #
        # Override this method in your wizard class to set a default visual theme
        # for documentation generation. If not overridden, defaults to :minimal.
        #
        # Available themes:
        # - **:detailed** - Professional, information-rich
        # - **:semantic** - Color-coded by meaning (intuitive branching)
        #
        # @return [Symbol, nil] The default theme (:minimal, :detailed, :semantic)
        #
        # @example Set default theme
        #   def documentation_theme
        #     :semantic
        #   end
        #
        # @example Conditional theming
        #   def documentation_theme
        #     :detailed
        #   end
        #
        # @api public
        def documentation_theme
          :detailed
        end
      end
    end
  end
end
