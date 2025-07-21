class WizardInfo
  attr_reader :klass, :namespace, :name, :start_path

  def initialize(klass:, namespace:, name:, start_path:)
    @klass = klass
    @namespace = namespace
    @name = name
    @start_path = start_path
  end

  def class_name
    klass.name
  end

  def doc_filename
    "#{klass.name.demodulize}.svg"
  end

  def doc_path
    "/doc/wizards/#{doc_filename}"
  end

  def link_to_start
    Rails.application.routes.url_helpers.send("#{namespace}_#{start_path}_path")
  end
end
