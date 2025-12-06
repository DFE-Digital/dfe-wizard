RSpec.describe DfE::Wizard::Documentation::Generator do
  subject(:generator) { described_class.new(metadata, options) }

  let(:wizard) { WorkExperienceWizard.new(state_store: WorkExperienceStateStore.new) }
  let(:metadata) { DfE::Wizard::Core::Metadata.new(wizard) }
  let(:options) { {} }
  let(:temp_dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(temp_dir) }

  describe 'initialization' do
    context 'with valid metadata' do
      it 'initializes successfully' do
        expect(generator).to be_a(described_class)
      end

      it 'sets metadata' do
        expect(generator.metadata).to eq(metadata)
      end

      it 'derives wizard_name from class' do
        expect(generator.wizard_name).to eq('Work experience wizard')
      end

      it 'normalizes options with defaults' do
        expect(generator.options).to include(
          step_attributes: true,
          step_validations: true,
          step_operations: true,
          include_raw_metadata: true,
        )
      end
    end

    context 'with custom title' do
      let(:options) { { title: 'Custom Wizard' } }

      it 'derives wizard_name from title' do
        expect(generator.wizard_name).to eq('Custom Wizard')
      end
    end

    context 'with custom options' do
      let(:options) do
        {
          step_attributes: false,
          step_validations: true,
          step_operations: false,
          include_raw_metadata: false,
        }
      end

      it 'sets custom options' do
        expect(generator.options).to eq(options)
      end
    end

    context 'with invalid metadata' do
      let(:metadata) { 'not metadata' }

      it 'raises ArgumentError' do
        expect { described_class.new(metadata) }
          .to raise_error(ArgumentError, /must respond to #to_h/)
      end
    end
  end

  describe '#generate' do
    context 'with built-in :markdown format' do
      it 'writes markdown file' do
        output_path = File.join(temp_dir, 'wizard.md')
        result = generator.generate(:markdown, output_path)

        expect(result).to eq(File.realpath(output_path))
        expect(File.exist?(output_path)).to be true
        expect(File.read(output_path)).to include('# Wizard Documentation')
      end

      it 'returns absolute path' do
        output_path = File.join(temp_dir, 'wizard.md')
        result = generator.generate(:markdown, output_path)

        expect(Pathname.new(result).absolute?).to be true
      end
    end

    context 'with built-in :mermaid format' do
      it 'writes mermaid file' do
        output_path = File.join(temp_dir, 'wizard.mmd')
        result = generator.generate(:mermaid, output_path)

        expect(result).to eq(File.realpath(output_path))
        expect(File.exist?(output_path)).to be true
        expect(File.read(output_path)).to include('flowchart')
      end
    end

    context 'with built-in :graphviz format' do
      it 'writes graphviz file' do
        output_path = File.join(temp_dir, 'wizard.dot')
        result = generator.generate(:graphviz, output_path)

        expect(result).to eq(File.realpath(output_path))
        expect(File.exist?(output_path)).to be true
        expect(File.read(output_path)).to include('digraph')
      end
    end

    context 'with custom formatter' do
      before do
        class TestFormatter
          def initialize(metadata, options)
            @metadata = metadata
            @options = options
          end

          def render
            'TEST_FORMAT_OUTPUT'
          end
        end
      end

      it 'uses custom formatter' do
        output_path = File.join(temp_dir, 'wizard.txt')
        result = generator.generate(:test, output_path)

        expect(result).to eq(File.realpath(output_path))
        expect(File.read(output_path)).to eq('TEST_FORMAT_OUTPUT')
      end
    end

    context 'with invalid format' do
      it 'raises ArgumentError' do
        output_path = File.join(temp_dir, 'wizard.xyz')

        expect { generator.generate(:unknown_format, output_path) }
          .to raise_error(ArgumentError, /Formatter not found for :unknown_format/)
      end

      it 'provides helpful error message' do
        output_path = File.join(temp_dir, 'wizard.xyz')

        expect { generator.generate(:invalid, output_path) }
          .to raise_error(ArgumentError) do |error|
            expect(error.message).to include('Expected format:')
            expect(error.message).to include(':markdown, :mermaid, :graphviz')
            expect(error.message).to include('To create a custom formatter:')
          end
      end
    end

    context 'with nested directory path' do
      it 'creates directories if needed' do
        nested_path = File.join(temp_dir, 'docs', 'sub', 'dir', 'wizard.md')
        result = generator.generate(:markdown, nested_path)

        expect(File.exist?(nested_path)).to be true
        expect(result).to eq(File.realpath(nested_path))
      end
    end

    context 'when directory not writable' do
      it 'raises error' do
        readonly_dir = File.join(temp_dir, 'readonly')
        FileUtils.mkdir(readonly_dir)
        FileUtils.chmod(0o444, readonly_dir)

        output_path = File.join(readonly_dir, 'wizard.md')

        begin
          expect { generator.generate(:markdown, output_path) }
            .to raise_error(Errno::EACCES)
        ensure
          FileUtils.chmod(0o755, readonly_dir)
        end
      end
    end
  end

  describe '#generate_all' do
    it 'generates all three formats' do
      result = generator.generate_all(temp_dir)

      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly(:markdown, :mermaid, :graphviz)
    end

    it 'creates markdown file with correct name' do
      generator.generate_all(temp_dir)
      markdown_path = File.join(temp_dir, 'work_experience_wizard.md')

      expect(File.exist?(markdown_path)).to be true
    end

    it 'creates mermaid file with correct name' do
      generator.generate_all(temp_dir)
      mermaid_path = File.join(temp_dir, 'work_experience_wizard.mmd')

      expect(File.exist?(mermaid_path)).to be true
    end

    it 'creates graphviz file with correct name' do
      generator.generate_all(temp_dir)
      graphviz_path = File.join(temp_dir, 'work_experience_wizard.dot')

      expect(File.exist?(graphviz_path)).to be true
    end

    it 'returns hash with absolute paths' do
      result = generator.generate_all(temp_dir)

      result.each_value do |path|
        expect(Pathname.new(path).absolute?).to be true
        expect(File.exist?(path)).to be true
      end
    end

    it 'returns paths matching generated files' do
      result = generator.generate_all(temp_dir)

      expect(result[:markdown]).to include('work_experience_wizard.md')
      expect(result[:mermaid]).to include('work_experience_wizard.mmd')
      expect(result[:graphviz]).to include('work_experience_wizard.dot')
    end

    context 'with custom title' do
      let(:options) { { title: 'My Custom Wizard' } }

      it 'uses custom title for filenames' do
        result = generator.generate_all(temp_dir)

        expect(result[:markdown]).to include('my_custom_wizard.md')
        expect(result[:mermaid]).to include('my_custom_wizard.mmd')
        expect(result[:graphviz]).to include('my_custom_wizard.dot')
      end
    end

    context 'when directory does not exist' do
      it 'creates the directory' do
        new_dir = File.join(temp_dir, 'new_docs')
        generator.generate_all(new_dir)

        expect(Dir.exist?(new_dir)).to be true
      end
    end

    context 'with custom options' do
      let(:options) do
        {
          step_attributes: false,
          step_validations: false,
          include_raw_metadata: false,
        }
      end

      it 'passes options to formatters' do
        result = generator.generate_all(temp_dir)
        markdown_content = File.read(result[:markdown])

        expect(markdown_content).not_to include('#### Attributes')
        expect(markdown_content).not_to include('#### Validations')
      end
    end
  end

  describe '#validate_metadata!' do
    context 'with object responding to #to_h' do
      it 'does not raise error' do
        expect { generator }.not_to raise_error
      end
    end

    context 'with object not responding to #to_h' do
      it 'raises ArgumentError' do
        expect { described_class.new('string') }
          .to raise_error(ArgumentError, /must respond to #to_h/)
      end
    end
  end

  describe '#formatter_for' do
    it 'returns MarkdownFormatter for :markdown' do
      formatter_class = generator.formatter_for(:markdown)
      expect(formatter_class).to eq(DfE::Wizard::Documentation::Formatters::MarkdownFormatter)
    end

    it 'returns MermaidFormatter for :mermaid' do
      formatter_class = generator.formatter_for(:mermaid)
      expect(formatter_class).to eq(DfE::Wizard::Documentation::Formatters::MermaidFormatter)
    end

    it 'returns GraphvizFormatter for :graphviz' do
      formatter_class = generator.formatter_for(:graphviz)
      expect(formatter_class).to eq(DfE::Wizard::Documentation::Formatters::GraphvizFormatter)
    end

    it 'constantizes custom formatter' do
      class CustomFormatter
        def render = 'custom'
      end

      formatter_class = generator.formatter_for(:custom)
      expect(formatter_class).to eq(CustomFormatter)
    end

    it 'raises error for unknown formatter' do
      expect { generator.formatter_for(:unknown) }
        .to raise_error(ArgumentError, /Formatter not found for :unknown/)
    end
  end

  describe '#filename' do
    it 'converts wizard name into filename' do
      expect(generator.filename).to eq('work_experience_wizard')
    end
  end

  describe '#write_file' do
    it 'writes content to file' do
      output_path = File.join(temp_dir, 'test.txt')
      generator.send(:write_file, output_path, 'Test content')

      expect(File.read(output_path)).to eq('Test content')
    end

    it 'returns absolute path' do
      output_path = File.join(temp_dir, 'test.txt')
      result = generator.send(:write_file, output_path, 'content')

      expect(Pathname.new(result).absolute?).to be true
    end

    it 'creates parent directories if needed' do
      output_path = File.join(temp_dir, 'a', 'b', 'c', 'test.txt')
      generator.send(:write_file, output_path, 'content')

      expect(File.exist?(output_path)).to be true
    end
  end

  describe 'integration' do
    it 'generates complete documentation package' do
      result = generator.generate_all(temp_dir)

      result.each_value { |path|
        expect(File.exist?(path)).to be true
        content = File.read(path)
        expect(content.length).to be > 100
      }

      markdown = File.read(result[:markdown])
      mermaid = File.read(result[:mermaid])
      graphviz = File.read(result[:graphviz])

      expect(markdown).to include('#')
      expect(mermaid).to include('flowchart')
      expect(graphviz).to include('digraph')
    end

    it 'respects custom options throughout' do
      custom_gen = described_class.new(
        metadata,
        step_attributes: true,
        step_validations: false,
        include_raw_metadata: false,
      )

      result = custom_gen.generate_all(temp_dir)
      markdown = File.read(result[:markdown])

      expect(markdown).to include('#### Attributes')
      expect(markdown).not_to include('#### Validations')
    end
  end
end
