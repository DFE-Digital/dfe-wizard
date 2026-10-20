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

RSpec.describe 'Edit errors' do
  [DfE::Wizard::NotCallable, DfE::Wizard::ChangesetMismatch,
   DfE::Wizard::ChangesetExpired, DfE::Wizard::StepNotAccessible].each do |error_class|
    it "#{error_class} is a StandardError and a DfE::Wizard::Error" do
      expect(error_class.new).to be_a(StandardError).and be_a(DfE::Wizard::Error)
    end
  end
end
