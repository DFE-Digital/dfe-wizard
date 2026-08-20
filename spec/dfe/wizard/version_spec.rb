RSpec.describe 'DfE::Wizard::VERSION' do
  # 1.0.0 shipped with `autoload :Version, 'dfe/wizard/version'`, which pointed
  # at a file defining `Dfe::Wizard::VERSION` (lowercase `e`) rather than a
  # `DfE::Wizard::Version` module. The autoload never resolved, so the gem could
  # not report its own version once loaded.
  it 'is defined on the namespace the library actually uses' do
    expect(defined?(DfE::Wizard::VERSION)).to eq('constant')
    expect(DfE::Wizard::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end

  it 'matches the version the gemspec builds' do
    gemspec = Gem::Specification.load(File.expand_path('../../../dfe-wizard.gemspec', __dir__))

    expect(gemspec.version.to_s).to eq(DfE::Wizard::VERSION)
  end

  it 'keeps the pre-1.0 Dfe spelling resolving to the same value' do
    expect(Dfe::Wizard::VERSION).to eq(DfE::Wizard::VERSION)
  end
end
