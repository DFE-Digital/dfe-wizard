RSpec.describe DfE::Wizard::InvalidGraph do
  it 'is an ArgumentError, so existing rescues still catch it' do
    expect(described_class.new('bad graph')).to be_a(ArgumentError)
  end

  it 'is a DfE::Wizard::Error' do
    expect(described_class.new('bad graph')).to be_a(DfE::Wizard::Error)
  end

  it 'is caught by rescue DfE::Wizard::Error' do
    message = begin
      raise described_class, 'bad graph'
    rescue DfE::Wizard::Error => e
      e.message
    end

    expect(message).to eq('bad graph')
  end
end
