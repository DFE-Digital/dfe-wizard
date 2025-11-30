namespace :wizard do
  namespace :docs do
    # Generate documentation for all wizards
    #
    # Generates GraphViz documentation for all wizard classes found in app/wizards
    # in all three themes (minimal, detailed, semantic).
    #
    # @example Generate all wizard documentation
    #   rake wizard:docs:generate
    #
    # @example Generate specific wizard
    #   WIZARD=PersonalInformationWizard rake wizard:docs:generate
    desc 'Generate documentation for all wizards'
    task generate: :environment do
      generator = WizardDocumentationGenerator.new
      generator.generate_all
    end

    # List all discovered wizards
    #
    # @example
    #   rake wizard:docs:list
    desc 'List all discovered wizards'
    task list: :environment do
      loader = WizardDocumentationLoader.new
      loader.print_list
    end

    # Clean generated documentation
    #
    # @example
    #   rake wizard:docs:clean
    desc 'Clean generated documentation'
    task clean: :environment do
      cleaner = WizardDocumentationCleaner.new
      cleaner.clean
    end
  end
end

# Generates documentation for wizards
#
# Loads all wizard classes and generates GraphViz documentation
# in all available themes.
#
# @api private
class WizardDocumentationGenerator
  THEMES = %i[minimal detailed semantic].freeze
  OUTPUT_DIR = Rails.root.join('docs/wizards/')

  def initialize
    @loader = WizardDocumentationLoader.new
    @output_dir = OUTPUT_DIR
  end

  # Generate documentation for all wizards
  def generate_all
    FileUtils.mkdir_p(@output_dir)

    specific_wizard = ENV['WIZARD']
    wizards = @loader.load_all

    wizards = wizards.select { |w| w.name == specific_wizard } if specific_wizard

    if wizards.empty?
      puts "❌ No wizards found#{specific_wizard ? " matching #{specific_wizard}" : ''}"
      return
    end

    puts "📚 Generating documentation for #{wizards.count} wizard(s) in #{THEMES.count} themes...\n"

    wizards.each do |wizard_class|
      generate_for_wizard(wizard_class)
    end

    puts "\n✅ Documentation generated in #{@output_dir.relative_path_from(Rails.root)}/"
  end

  private

  # Generate documentation for a single wizard in all themes
  #
  # @param wizard_class [Class]
  def generate_for_wizard(wizard_class)
    puts "  🧙 #{wizard_class.name}"

    wizard = instantiate_wizard(wizard_class)

    THEMES.each do |theme|
      generate_for_theme(wizard, wizard_class, theme)
    end
  end

  # Generate documentation for a specific theme
  #
  # @param wizard [Object] Wizard instance
  # @param wizard_class [Class]
  # @param theme [Symbol]
  def generate_for_theme(wizard, wizard_class, theme)
    safe_name = wizard_class.name.gsub('::', '_').underscore
    theme_dir = File.join(@output_dir, theme.to_s)
    FileUtils.mkdir_p(theme_dir)

    begin
      doc = wizard.to_doc(theme:)
      svg_path = File.join(theme_dir, "#{safe_name}.svg")
      png_path = File.join(theme_dir, "#{safe_name}.png")

      doc.output(svg: svg_path)
      doc.output(png: png_path)

      puts "    ✓ #{theme.to_s.ljust(10)} → SVG, PNG"
    rescue StandardError => e
      puts "    ✗ #{theme.to_s.ljust(10)} → Error: #{e.message}"
    end
  end

  # Instantiate a wizard with dummy state
  #
  # @param wizard_class [Class]
  # @return [Object, nil]
  def instantiate_wizard(wizard_class)
    wizard_class.new(current_step: :start, state_store: OpenStruct.new(repository: OpenStruct.new))
  end
end

# Loads and discovers wizard classes
#
# @api private
class WizardDocumentationLoader
  def initialize
    @wizards = nil
  end

  # Load all wizard classes from app/wizards
  #
  # @return [Array<Class>]
  def load_all
    @wizards ||= discover_wizards
  end

  # Print list of discovered wizards
  def print_list
    wizards = load_all

    if wizards.empty?
      puts '❌ No wizards found'
      return
    end

    puts "Found #{wizards.count} wizard(s):\n\n"
    wizards.each { |w| puts "  • #{w.name}" }
  end

  private

  # Discover all wizard classes
  #
  # @return [Array<Class>]
  def discover_wizards
    load_wizard_files
    find_wizard_classes.sort_by(&:name)
  end

  # Load all wizard files from app/wizards
  def load_wizard_files
    wizards_dir = Rails.root.join('app', 'wizards')
    return unless File.directory?(wizards_dir)

    # Exclude subdirectories
    Dir.glob("#{wizards_dir}/*.rb").each { |file| require file }
  end

  # Find all wizard classes
  #
  # @return [Array<Class>]
  def find_wizard_classes
    results = Object.constants.select do |const_name|
      next unless const_name.to_s.downcase.include? 'wizard'

      klass = Object.const_get(const_name)

      klass.respond_to?(:included_modules) && klass.included_modules.include?(DfE::Wizard)
    end

    results.compact.map { |const_name| Object.const_get(const_name) }
  end
end

# Cleans generated documentation
#
# @api private
class WizardDocumentationCleaner
  OUTPUT_DIR = Rails.root.join('wizard-docs-generated-example')

  def clean
    if File.directory?(OUTPUT_DIR)
      FileUtils.rm_rf(OUTPUT_DIR)
      puts "✅ Cleaned #{OUTPUT_DIR.relative_path_from(Rails.root)}/"
    else
      puts 'ℹ️  No documentation directory found'
    end
  end
end
