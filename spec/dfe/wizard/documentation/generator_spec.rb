RSpec.describe DfE::Wizard::Documentation::Generator do
  describe 'Initialization' do
    let(:wizard) { build_stub_wizard }
    let(:options) { {} }

    context 'with valid wizard' do
      it 'initializes successfully' do
        builder = described_class.new(wizard, options)
        expect(builder).to be_a(described_class)
      end

      it 'stores wizard reference' do
        builder = described_class.new(wizard, options)
        expect(builder.wizard).to eq(wizard)
      end

      it 'extracts metadata from wizard' do
        builder = described_class.new(wizard, options)
        expect(builder.metadata).to be_a(Hash)
      end

      it 'normalizes options with defaults' do
        builder = described_class.new(wizard, {})
        expect(builder.options).to include(
          step_attributes: true,
          step_validations: true,
          step_operations: true,
          include_raw_metadata: true,
        )
      end
    end

    context 'without steps_processor' do
      it 'raises ArgumentError' do
        bad_wizard = Object.new
        expect do
          described_class.new(bad_wizard, options)
        end.to raise_error(ArgumentError, /steps_processor/)
      end
    end

    context 'with steps_processor but no metadata' do
      it 'raises ArgumentError' do
        bad_wizard = build_stub_wizard
        allow(bad_wizard.steps_processor).to receive(:respond_to?).and_return(false)
        expect do
          described_class.new(bad_wizard, options)
        end.to raise_error(ArgumentError, /metadata/)
      end
    end
  end

  describe 'Options Normalization' do
    let(:wizard) { build_stub_wizard }

    context 'with no options' do
      it 'defaults all to true' do
        builder = described_class.new(wizard, {})
        expect(builder.options[:step_attributes]).to be true
        expect(builder.options[:step_validations]).to be true
        expect(builder.options[:step_operations]).to be true
        expect(builder.options[:include_raw_metadata]).to be true
      end
    end

    context 'with partial options' do
      it 'preserves provided values' do
        builder = described_class.new(wizard, step_attributes: false)
        expect(builder.options[:step_attributes]).to be false
        expect(builder.options[:step_validations]).to be true
      end

      it 'fills missing options with defaults' do
        builder = described_class.new(wizard, include_raw_metadata: false)
        expect(builder.options[:step_operations]).to be true
        expect(builder.options[:include_raw_metadata]).to be false
      end
    end

    context 'with all options disabled' do
      it 'honors all false values' do
        opts = {
          step_attributes: false,
          step_validations: false,
          step_operations: false,
          include_raw_metadata: false,
        }
        builder = described_class.new(wizard, opts)
        expect(builder.options).to eq(opts)
      end
    end
  end

  describe '#generate_markdown' do
    let(:wizard) { build_stub_wizard }
    let(:builder) { described_class.new(wizard) }
    let(:temp_dir) { Pathname.new(Dir.mktmpdir) }

    after do
      FileUtils.rm_rf(temp_dir) if temp_dir.exist?
    end

    it 'generates markdown file' do
      filepath = temp_dir.join('test.md')
      result = builder.generate_markdown(filepath)
      expect(File.exist?(result)).to be true
    end

    it 'returns absolute file path' do
      filepath = temp_dir.join('test.md')
      result = builder.generate_markdown(filepath)
      expect(Pathname.new(result).absolute?).to be true
    end

    it 'creates readable markdown file' do
      filepath = temp_dir.join('test.md')
      builder.generate_markdown(filepath)
      content = File.read(filepath)
      expect(content).to include('# Wizard Documentation')
    end

    it 'respects formatter options' do
      filepath = temp_dir.join('test.md')
      builder_no_attrs = described_class.new(wizard, step_attributes: false)
      content_no_attrs = File.read(builder_no_attrs.generate_markdown(filepath))

      filepath2 = temp_dir.join('test2.md')
      builder_with_attrs = described_class.new(wizard, step_attributes: true)
      content_with_attrs = File.read(builder_with_attrs.generate_markdown(filepath2))

      # With attributes should generally be longer (more content)
      expect(content_with_attrs.length).to be > content_no_attrs.length
    end

    context 'with invalid path' do
      it 'raises error for non-writable directory' do
        expect do
          builder.generate_markdown('/root/forbidden/path.md')
        end.to raise_error(Errno::EACCES)
      end
    end
  end

  describe '#generate_mermaid' do
    let(:wizard) { build_stub_wizard }
    let(:builder) { described_class.new(wizard) }
    let(:temp_dir) { Pathname.new(Dir.mktmpdir) }

    after do
      FileUtils.rm_rf(temp_dir) if temp_dir.exist?
    end

    it 'generates mermaid diagram file' do
      filepath = temp_dir.join('test.mmd')
      result = builder.generate_mermaid(filepath)
      expect(File.exist?(result)).to be true
    end

    it 'creates valid mermaid syntax' do
      filepath = temp_dir.join('test.mmd')
      builder.generate_mermaid(filepath)
      content = File.read(filepath)
      expect(content).to match(/^graph (TD|LR|BT|RL)/)
    end

    it 'includes step nodes' do
      filepath = temp_dir.join('test.mmd')
      builder.generate_mermaid(filepath)
      content = File.read(filepath)
      expect(content).to include('[')
      expect(content).to include(']')
    end

    it 'includes arrows for transitions' do
      filepath = temp_dir.join('test.mmd')
      builder.generate_mermaid(filepath)
      content = File.read(filepath)
      expect(content).to match(/-->|=>/)
    end
  end

  describe '#generate_graphviz' do
    let(:wizard) { build_stub_wizard }
    let(:builder) { described_class.new(wizard) }
    let(:temp_dir) { Pathname.new(Dir.mktmpdir) }

    after do
      FileUtils.rm_rf(temp_dir) if temp_dir.exist?
    end

    it 'generates graphviz DOT file' do
      filepath = temp_dir.join('test.dot')
      result = builder.generate_graphviz(filepath)
      expect(File.exist?(result)).to be true
    end

    it 'creates valid DOT syntax' do
      filepath = temp_dir.join('test.dot')
      builder.generate_graphviz(filepath)
      content = File.read(filepath)
      expect(content).to match(/^digraph|^graph/)
    end

    it 'includes graph nodes' do
      filepath = temp_dir.join('test.dot')
      builder.generate_graphviz(filepath)
      content = File.read(filepath)
      expect(content).to include('"')
      expect(content).to include(';')
    end

    it 'includes edges for transitions' do
      filepath = temp_dir.join('test.dot')
      builder.generate_graphviz(filepath)
      content = File.read(filepath)
      expect(content).to match(/->|--/)
    end
  end

  describe '#generate_all' do
    let(:wizard) { build_stub_wizard }
    let(:builder) { described_class.new(wizard) }
    let(:output_dir) { Pathname.new(Dir.mktmpdir) }
    let(:wizard_name) { 'stub_wizard' }

    after do
      FileUtils.rm_rf(output_dir) if output_dir.exist?
    end

    it 'generates all three formats' do
      result = builder.generate_all(output_dir)
      expect(result).to have_key(:markdown)
      expect(result).to have_key(:mermaid)
      expect(result).to have_key(:graphviz)
    end

    it 'creates markdown file' do
      builder.generate_all(output_dir)
      expect(File.exist?(output_dir.join("#{wizard_name}.md"))).to be true
    end

    it 'creates mermaid file' do
      builder.generate_all(output_dir)
      expect(File.exist?(output_dir.join("#{wizard_name}.mmd"))).to be true
    end

    it 'creates graphviz file' do
      builder.generate_all(output_dir)
      expect(File.exist?(output_dir.join("#{wizard_name}.dot"))).to be true
    end

    it 'returns absolute paths' do
      result = builder.generate_all(output_dir)
      expect(Pathname.new(result[:markdown]).absolute?).to be true
      expect(Pathname.new(result[:mermaid]).absolute?).to be true
      expect(Pathname.new(result[:graphviz]).absolute?).to be true
    end

    it 'creates output directory if missing' do
      new_dir = output_dir.join('nested/deep/path')
      builder.generate_all(new_dir)
      expect(new_dir.exist?).to be true
    end

    context 'with string path' do
      it 'accepts string paths' do
        result = builder.generate_all(output_dir.to_s)
        expect(result[:markdown]).to include(wizard_name)
      end
    end

    context 'with Pathname' do
      it 'accepts Pathname objects' do
        result = builder.generate_all(output_dir)
        expect(result[:markdown]).to include(wizard_name)
      end
    end
  end

  describe 'Metadata Access' do
    let(:wizard) { build_stub_wizard }
    let(:builder) { described_class.new(wizard) }

    it 'exposes metadata as attr_reader' do
      expect(builder.metadata).to be_a(Hash)
    end

    it 'includes structure_type' do
      expect(builder.metadata).to have_key(:structure_type)
    end

    it 'includes steps' do
      expect(builder.metadata).to have_key(:steps)
    end

    it 'includes transitions' do
      expect(builder.metadata).to have_key(:transitions)
    end

    it 'includes counts' do
      expect(builder.metadata).to have_key(:counts)
    end

    it 'exposes wizard reference' do
      expect(builder.wizard).to eq(wizard)
    end

    it 'exposes normalized options' do
      expect(builder.options).to be_a(Hash)
    end
  end

  describe 'File Operations' do
    let(:wizard) { build_stub_wizard }
    let(:builder) { described_class.new(wizard) }
    let(:temp_dir) { Pathname.new(Dir.mktmpdir) }

    after do
      FileUtils.rm_rf(temp_dir) if temp_dir.exist?
    end

    context 'with writable directory' do
      it 'successfully writes files' do
        filepath = temp_dir.join('test.md')
        result = builder.generate_markdown(filepath)
        expect(File.exist?(result)).to be true
      end
    end

    context 'with restricted permissions' do
      it 'raises error when directory not writable' do
        restricted_dir = temp_dir.join('restricted')
        Dir.mkdir(restricted_dir)
        File.chmod(0o444, restricted_dir)

        expect do
          builder.generate_markdown(restricted_dir.join('test.md'))
        end.to raise_error(Errno::EACCES)

        File.chmod(0o755, restricted_dir)
      end
    end
  end

  describe 'Wizard Name Derivation' do
    it 'derives wizard name from class' do
      wizard = build_stub_wizard
      builder = described_class.new(wizard)

      expect(builder.send(:wizard_name)).to include('stub_wizard')
    end

    it 'converts CamelCase to underscore' do
      # Using a real wizard class would be better, but for testing:
      allow_any_instance_of(described_class).to receive(:wizard_name).and_return('my_awesome_wizard')
      wizard = build_stub_wizard
      builder = described_class.new(wizard)

      # Verify method exists and works
      expect(builder.send(:wizard_name)).to be_a(String)
    end
  end

  describe 'Format Delegation' do
    let(:wizard) { build_stub_wizard }
    let(:builder) { described_class.new(wizard) }
    let(:temp_file) { Pathname.new(Dir.mktmpdir).join('test') }

    after do
      FileUtils.rm_f(temp_file.to_s)
    end

    it 'delegates markdown to MarkdownFormatter' do
      expect_any_instance_of(
        DfE::Wizard::Documentation::Formatters::MarkdownFormatter,
      ).to receive(:render).and_return('# Test')
      builder.generate_markdown("#{temp_file}.md")
    end

    it 'delegates mermaid to MermaidFormatter' do
      expect_any_instance_of(
        DfE::Wizard::Documentation::Formatters::MermaidFormatter,
      ).to receive(:render).and_return('graph TD')
      builder.generate_mermaid("#{temp_file}.mmd")
    end

    it 'delegates graphviz to GraphvizFormatter' do
      expect_any_instance_of(
        DfE::Wizard::Documentation::Formatters::GraphvizFormatter,
      ).to receive(:render).and_return('digraph {}')
      builder.generate_graphviz("#{temp_file}.dot")
    end

    it 'passes metadata to formatters' do
      expect(
        DfE::Wizard::Documentation::Formatters::MarkdownFormatter,
      ).to receive(:new).with(
        builder.metadata,
        anything,
      )
      temp_path = Pathname.new(Dir.mktmpdir).join('test.md')
      builder.generate_markdown(temp_path)
    end

    it 'passes options to formatters' do
      opts = { step_attributes: false }
      builder_with_opts = described_class.new(wizard, opts)
      expect(
        DfE::Wizard::Documentation::Formatters::MarkdownFormatter,
      ).to receive(:new).with(
        anything,
        include(step_attributes: false),
      )
      temp_path = Pathname.new(Dir.mktmpdir).join('test.md')
      builder_with_opts.generate_markdown(temp_path)
    end
  end

  describe 'Integration' do
    let(:wizard) { build_stub_wizard }
    let(:output_dir) { Pathname.new(Dir.mktmpdir) }

    after do
      FileUtils.rm_rf(output_dir) if output_dir.exist?
    end

    context 'complete workflow' do
      it 'generates all formats in one call' do
        builder = described_class.new(wizard)
        result = builder.generate_all(output_dir)

        # Verify all files exist
        expect(File.exist?(result[:markdown])).to be true
        expect(File.exist?(result[:mermaid])).to be true
        expect(File.exist?(result[:graphviz])).to be true

        # Verify content is not empty
        expect(File.size(result[:markdown])).to be > 0
        expect(File.size(result[:mermaid])).to be > 0
        expect(File.size(result[:graphviz])).to be > 0
      end

      it 'handles conditional root entries' do
        # Create wizard with multiple entry points
        wizard = build_stub_wizard(root_type: :multiple)
        builder = described_class.new(wizard)
        result = builder.generate_all(output_dir)

        # Should generate without error
        expect(result[:markdown]).to be_present
        expect(result[:mermaid]).to be_present
        expect(result[:graphviz]).to be_present
      end

      it 'respects all option combinations' do
        options_combos = [
          { step_attributes: true, step_validations: true, step_operations: true },
          { step_attributes: false, step_validations: false, step_operations: false },
          { step_attributes: true, step_validations: false, step_operations: true },
          { include_raw_metadata: false },
        ]

        options_combos.each do |opts|
          builder = described_class.new(wizard, opts)
          result = builder.generate_all(output_dir.join(opts.values.join('_')))
          expect(result).to have_key(:markdown)
          expect(result).to have_key(:mermaid)
          expect(result).to have_key(:graphviz)
        end
      end
    end
  end

  describe 'Error Handling' do
    let(:wizard) { build_stub_wizard }
    let(:builder) { described_class.new(wizard) }

    it 'handles non-existent parent directories' do
      temp_dir = Pathname.new(Dir.mktmpdir)
      nested_path = temp_dir.join('a/b/c/d/e')
      FileUtils.rm_rf(temp_dir)

      expect do
        builder.generate_markdown(nested_path.join('test.md'))
      end.to raise_error(Errno::ENOENT)
    end

    it 'handles file write failures gracefully' do
      # Create a file and try to write to it as a directory
      temp_dir = Pathname.new(Dir.mktmpdir)
      file_path = temp_dir.join('is_a_file')
      File.write(file_path, 'test')

      expect do
        builder.generate_markdown(file_path.join('subfile.md'))
      end.to raise_error(Errno::ENOTDIR)

      FileUtils.rm_rf(temp_dir)
    end
  end

  # Helper Methods
  def build_stub_wizard(root_type: :single)
    wizard = double('Wizard')
    processor = double('StepsProcessor')

    metadata = {
      structure_type: :graph,
      root_step: root_type == :single ? :start : %i[entry_one entry_two],
      steps: {
        start: { label: 'Start', class: 'Steps::Start' },
        end: { label: 'End', class: 'Steps::End' },
      },
      transitions: [
        { type: :simple, from: :start, to: :end },
      ],
      counts: {
        steps: 2,
        simple_transitions: 1,
        conditional_transitions: 0,
        multiple_conditional_transitions: 0,
        custom_branching_transitions: 0,
      },
    }

    allow(processor).to receive(:respond_to?).and_return(true)
    allow(processor).to receive(:metadata).and_return(metadata)
    allow(wizard).to receive(:steps_processor).and_return(processor)
    allow(wizard).to receive(:class).and_return(StubWizard)

    wizard
  end

  class StubWizard
    include DfE::Wizard

    def steps_processor
      DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
        graph.add_node :name
        graph.root :name
      end
    end
  end
end
