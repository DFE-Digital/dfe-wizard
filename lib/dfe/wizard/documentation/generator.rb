# frozen_string_literal: true

module DfE
  module Wizard
    module Documentation
      # Documentation orchestrator for wizard metadata.
      #
      # Generates comprehensive documentation in multiple formats (Markdown, Mermaid, Graphviz)
      # from unified wizard metadata. Pure data processor: receives metadata, returns formatted output.
      #
      # Processor-agnostic: works with any metadata object that responds to #to_h.
      #
      # @example Usage with wizard
      #   wizard = MyWizard.new(state_store: store)
      #   docs = DfE::Wizard::Documentation::Generator.new(wizard.metadata)
      #   docs.generate_all('docs/wizards')
      #
      # @example Usage with metadata directly
      #   metadata = Core::Metadata.new(wizard)
      #   docs = Generator.new(metadata, step_attributes: false)
      #   docs.generate(:markdown, 'output.md')
      #
      # @api public
      # @since 3.0.0
      class Generator
        FORMATTERS = {
          markdown: Formatters::MarkdownFormatter,
          mermaid: Formatters::MermaidFormatter,
          graphviz: Formatters::GraphvizFormatter,
        }.freeze

        # Access raw metadata (for advanced use cases)
        #
        # @return [DfE::Wizard::Core::Metadata] The metadata instance
        attr_reader :metadata

        # Access normalized options
        #
        # @return [Hash] Configuration options with defaults applied
        attr_reader :options

        # Wizard name derived from metadata
        #
        # @return [String] Name for generated files (lowercase, snake_case)
        attr_reader :wizard_name

        # Filename generated in output dir
        #
        # @return [String] Name for generated files (lowercase, snake_case)
        attr_reader :filename

        # Initialize documentation generator
        #
        # @param metadata [DfE::Wizard::Core::Metadata] The metadata to document
        # @param user_options [Hash] Configuration options
        # @option user_options [Boolean] :step_attributes (true) Include step attributes in docs
        # @option user_options [Boolean] :step_validations (true) Include step validations in docs
        # @option user_options [Boolean] :step_operations (true) Include step operations in docs
        # @option user_options [Boolean] :include_raw_metadata (true) Include raw JSON metadata
        # @option user_options [String] :title Custom documentation title (defaults to metadata class name)
        #
        # @raise [ArgumentError] If metadata doesn't respond to #to_h
        #
        # @example
        #   metadata = wizard.metadata
        #   gen = Generator.new(metadata, step_attributes: false)
        def initialize(metadata, user_options = {})
          validate_metadata!(metadata)

          @metadata = metadata
          @wizard_name = user_options[:title] || metadata[:wizard_name].to_s.force_encoding('utf-8')
          @filename = @wizard_name.parameterize.underscore

          @options = {
            step_attributes: true,
            step_validations: true,
            step_operations: true,
            include_raw_metadata: true,
          }.merge(user_options)
        end

        # Generate documentation in specified format to file
        #
        # Supported formats:
        # - **:markdown** - Human-readable narrative documentation
        # - **:mermaid** - Interactive flowchart (embed in docs)
        # - **:graphviz** - Professional directed graph (export to PDF/PNG)
        #
        # @param format [Symbol] Output format (:markdown, :mermaid, :graphviz)
        # @param filepath [String, Pathname] Output file path
        #
        # @return [String] Absolute path to generated file
        #
        # @raise [ArgumentError] If format not supported
        # @raise [Errno::EACCES] If filepath not writable
        # @raise [Errno::ENOENT] If directory doesn't exist
        #
        # @example Generate Markdown
        #   docs.generate(:markdown, 'docs/wizard.md')
        #   # => "/full/path/to/docs/wizard.md"
        #
        # @example Generate Mermaid flowchart
        #   docs.generate(:mermaid, 'docs/wizard.mmd')
        #
        # @example Generate Graphviz diagram
        #   docs.generate(:graphviz, 'docs/wizard.dot')
        #
        # @api public
        def generate(format, filepath)
          formatter_class = formatter_for(format)
          formatter = formatter_class.new(@metadata.to_h, @options)
          content = formatter.render
          write_file(filepath, content)
        end

        # Generate all documentation formats to specified directory
        #
        # Creates three files with consistent naming:
        # - {wizard_name}.md (Markdown documentation)
        # - {wizard_name}.mmd (Mermaid diagram)
        # - {wizard_name}.dot (Graphviz diagram)
        #
        # @param output_dir [String, Pathname] Directory to write files
        #
        # @return [Hash{Symbol => String}] Absolute paths to generated files
        #
        # @raise [Errno::EACCES] If directory not writable
        # @raise [Errno::ENOENT] If directory can't be created
        #
        # @example
        #   docs.generate_all('docs/wizards')
        #   # => {
        #   #   markdown: "/full/path/to/docs/wizards/my_wizard.md",
        #   #   mermaid: "/full/path/to/docs/wizards/my_wizard.mmd",
        #   #   graphviz: "/full/path/to/docs/wizards/my_wizard.dot"
        #   # }
        #
        # @api public
        def generate_all(output_dir)
          output_dir = Pathname.new(output_dir)
          ensure_directory_exists(output_dir)

          {
            markdown: generate(:markdown, output_dir.join("#{@filename}.md")),
            mermaid: generate(:mermaid, output_dir.join("#{@filename}.mmd")),
            graphviz: generate(:graphviz, output_dir.join("#{@filename}.dot")),
          }
        end

        # Validate metadata responds to #to_h
        #
        # @param metadata [Object] Metadata object to validate
        # @raise [ArgumentError] If metadata invalid
        # @api private
        def validate_metadata!(metadata)
          return if metadata.respond_to?(:to_h)

          raise ArgumentError, "Metadata must respond to #to_h, got #{metadata.class}"
        end

        # Get formatter class for format symbol
        #
        # @param format [Symbol] Format identifier
        # @return [Class] Formatter class
        # @raise [ArgumentError] If format not supported
        # @api private
        def formatter_for(format)
          formatter_class = FORMATTERS[format]

          return formatter_class if formatter_class.present?

          begin
            class_name = "#{format.to_s.classify}Formatter"

            class_name.constantize
          rescue NameError
            raise ArgumentError, <<~MESSAGE.squish
              Formatter not found for #{format.inspect}

              Expected format: #{FORMATTERS.keys}

              To create a custom formatter:
              1. Create class: #{class_name}
              2. Implement: initialize(metadata, options) and render() → String
              3. Call: generate(#{format.inspect}, filepath)
            MESSAGE
          end
        end

        # Ensure output directory exists
        #
        # @param dir [Pathname] Directory path
        # @raise [Errno::EACCES] If directory can't be created
        # @api private
        def ensure_directory_exists(dir)
          FileUtils.mkdir_p(dir) unless dir.exist?
        end

        # Write content to file
        #
        # @param filepath [String, Pathname] Output path
        # @param content [String] File content
        # @return [String] Absolute path to written file
        # @raise [Errno::EACCES] If file not writable
        # @api private
        def write_file(filepath, content)
          filepath = Pathname.new(filepath)
          ensure_directory_exists(filepath.parent)
          File.write(filepath, content)
          filepath.realpath.to_s
        end
      end
    end
  end
end
