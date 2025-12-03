module DfE
  module Wizard
    # Documentation orchestrator for wizard step processors.
    #
    # Generates comprehensive documentation in multiple formats (Markdown, Mermaid, Graphviz)
    # from unified wizard metadata. Processor-agnostic: works with any DfE::Wizard::StepsProcessor.
    #
    # @example Usage
    #   wizard = MyWizard.new
    #   docs = wizard.documentation(
    #     step_attributes: true,
    #     step_validations: true,
    #     step_operations: true
    #   )
    #   docs.generate_all('docs/wizards')
    #
    # @example Individual format generation
    #   docs.generate_markdown('docs/my_wizard.md')
    #   docs.generate_mermaid('docs/my_wizard.mmd')
    #   docs.generate_graphviz('docs/my_wizard.dot')
    module Documentation
      class Generator
        # Access raw metadata (for advanced use cases).
        #
        # @return [Hash] Complete wizard metadata in unified format
        #
        # @example
        #   docs = wizard.documentation
        #   metadata = docs.metadata
        #   puts metadata[:structure_type]  # => :graph or :linear
        #   puts metadata[:counts][:steps]  # => 9
        attr_reader :metadata

        # Access wizard instance (for advanced use cases).
        #
        # @return [DfE::Wizard::Base] The wizard being documented
        attr_reader :wizard

        # Access normalized options.
        #
        # @return [Hash] Configuration options with defaults applied
        attr_reader :options

        # Wizard name.
        #
        # @return [String] Name of the wizard based on class name
        attr_reader :wizard_name

        # Initialize documentation generator.
        #
        # @param wizard [DfE::Wizard::Base] The wizard instance
        # @param options [Hash] Configuration options
        # @option options [Boolean] :step_attributes (true) Include step attributes in docs
        # @option options [Boolean] :step_validations (true) Include step validations in docs
        # @option options [Boolean] :step_operations (true) Include step operations in docs
        # @option options [Boolean] :include_raw_metadata (true) Include raw JSON metadata
        # @raise [ArgumentError] If wizard doesn't have steps_processor

        def initialize(wizard, options = {})
          @wizard = wizard
          @options = normalize_options(options)
          @metadata = wizard.metadata
          @wizard_name = @wizard.class.name.demodulize.underscore
        end

        # Generate all documentation formats to specified directory.
        #
        # Creates three files:
        # - {wizard_name}.md (Markdown documentation)
        # - {wizard_name}.mmd (Mermaid diagram)
        # - {wizard_name}.dot (Graphviz diagram)
        #
        # @param output_dir [String, Pathname] Directory to write documentation files
        # @return [Hash{Symbol => String}] Paths to generated files: { markdown:, mermaid:, graphviz: }
        # @raise [Errno::ENOENT] If directory doesn't exist and can't be created
        # @raise [Errno::EACCES] If directory isn't writable
        #
        # @example
        #   docs = wizard.documentation
        #   files = docs.generate_all('docs/wizards')
        #   puts files[:markdown]  # => "docs/wizards/my_wizard.md"
        def generate_all(output_dir)
          output_dir = Pathname.new(output_dir)
          ensure_directory_exists(output_dir)

          {
            markdown: generate_markdown(output_dir.join("#{wizard_name}.md")),
            mermaid: generate_mermaid(output_dir.join("#{wizard_name}.mmd")),
            graphviz: generate_graphviz(output_dir.join("#{wizard_name}.dot")),
          }
        end

        # Generate Markdown documentation to file.
        #
        # Produces a detailed, human-readable narrative documentation including:
        # - Overview and business context
        # - Root entry points (with conditional logic explained)
        # - ASCII flow diagram
        # - Complete step reference with attributes, validations, operations
        # - Detailed transition explanations (all types)
        # - Wizard statistics and possible user journeys
        # - Raw JSON metadata
        #
        # @param filepath [String, Pathname] Output file path
        # @return [String] Absolute path to generated file
        # @raise [Errno::EACCES] If file isn't writable
        #
        # @example
        #   docs = wizard.documentation
        #   docs.generate_markdown('docs/my_wizard.md')
        def generate_markdown(filepath)
          formatter = Formatters::MarkdownFormatter.new(@metadata, @options)
          content = formatter.render
          write_file(filepath, content)
        end

        # Generate Mermaid diagram to file.
        #
        # Produces an interactive flowchart diagram suitable for:
        # - Embedding in documentation sites
        # - Sharing in design documents
        # - Creating visual presentations
        #
        # Syntax: Mermaid flowchart (TD = top-down layout)
        #
        # @param filepath [String, Pathname] Output file path
        # @return [String] Absolute path to generated file
        # @raise [Errno::EACCES] If file isn't writable
        #
        # @example
        #   docs = wizard.documentation
        #   docs.generate_mermaid('docs/my_wizard.mmd')
        #
        # @see https://mermaid-js.github.io/mermaid/
        def generate_mermaid(filepath)
          formatter = Formatters::MermaidFormatter.new(@metadata, @options)
          content = formatter.render
          write_file(filepath, content)
        end

        # Generate Graphviz (DOT format) diagram to file.
        #
        # Produces a professional directed graph diagram suitable for:
        # - High-resolution PDF/PNG export
        # - Academic/formal documentation
        # - Complex workflow visualization
        #
        # Can be compiled with: dot -Tpdf diagram.dot -o diagram.pdf
        #
        # @param filepath [String, Pathname] Output file path
        # @return [String] Absolute path to generated file
        # @raise [Errno::EACCES] If file isn't writable
        #
        # @example
        #   docs = wizard.documentation
        #   docs.generate_graphviz('docs/my_wizard.dot')
        #   # Then compile: dot -Tpng docs/my_wizard.dot -o docs/my_wizard.png
        #
        # @see https://graphviz.org/
        def generate_graphviz(filepath)
          formatter = Formatters::GraphvizFormatter.new(@metadata, @options)
          content = formatter.render
          write_file(filepath, content)
        end

        private

        # Normalize user-supplied options to documented defaults.
        #
        # @param user_options [Hash] Options from initializer
        # @return [Hash] Normalized options with all keys present
        def normalize_options(user_options)
          {
            step_attributes: user_options.fetch(:step_attributes, true),
            step_validations: user_options.fetch(:step_validations, true),
            step_operations: user_options.fetch(:step_operations, true),
            include_raw_metadata: user_options.fetch(:include_raw_metadata, true),
          }
        end

        # Ensure output directory exists, creating it if necessary.
        #
        # @param dir [Pathname] Directory path
        # @raise [Errno::EACCES] If directory can't be created
        def ensure_directory_exists(dir)
          FileUtils.mkdir_p(dir) unless dir.exist?
        end

        # Write formatted content to file.
        #
        # @param filepath [String, Pathname] Output file path
        # @param content [String] File content
        # @return [String] Absolute path to written file
        # @raise [Errno::EACCES] If file isn't writable
        def write_file(filepath, content)
          filepath = Pathname.new(filepath)
          File.write(filepath, content)
          filepath.realpath.to_s
        end
      end
    end
  end
end
