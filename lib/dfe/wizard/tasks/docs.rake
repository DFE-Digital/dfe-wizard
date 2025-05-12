namespace :wizards do
  namespace :docs do
    desc 'Generate documentation for a specific wizard class.'
    task :generate, [:wizard_class] do |_t, args|
      if defined?(Rails)
        Rake::Task['environment'].invoke
      end

      wizard_class = begin
        args[:wizard_class].constantize
      rescue StandardError
        nil
      end

      unless wizard_class && wizard_class < DfE::Wizard::Base
        abort "Invalid wizard class: #{args[:wizard_class]}"
      end

      output_dir = Rails.root.join('doc/wizards')
      FileUtils.mkdir_p(output_dir)

      graph = wizard_class.new(current_step: nil).to_doc
      format = ENV['FORMAT'] || 'png'
      output_file = output_dir.join("#{wizard_class.name.underscore}.#{format}")

      graph.output(format.to_sym => output_file)
      puts "Generated #{File.expand_path(output_file)}"
    end

    desc 'Generate documentation for all registered wizards'
    task :all do
      if defined?(Rails)
        Rake::Task['environment'].invoke
      end

      wizards = DfE::Wizard::Base.descendants
      abort 'No wizards found that inherits from DfE::Wizard::Base' if wizards.empty?

      wizards.each do |wizard_class|
        Rake::Task['wizards:docs:generate'].invoke(wizard_class.name)
        Rake::Task['wizards:docs:generate'].reenable
      end
    end
  end
end
