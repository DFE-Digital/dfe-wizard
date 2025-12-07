class FeatureFlag
  @flags = {}

  def self.activate(flag_name)
    @flags[flag_name] = true
  end

  def self.deactivate(flag_name)
    @flags[flag_name] = false
  end

  def self.active?(flag_name)
    @flags[flag_name].present?
  end

  def self.reset
    @flags = {}
  end
end
