RSpec.describe Repositories::ALevelsRequirements do
  describe '#write' do
    it 'write pending a level to the right column' do
      record = create(:course)
      expect(record.accept_pending_a_level).to be_nil

      described_class.new(record:).write(pending_a_level: true)

      expect(record.reload.accept_pending_a_level).to be true

      described_class.new(record:).write(pending_a_level: false)
      expect(record.reload.accept_pending_a_level).to be false
    end

    it 'ignores virtual attributes' do
      record = create(:course)
      repository = described_class.new(record:)

      repository.write(add_another_a_level: 'yes')

      expect(repository.virtual_attributes).to eq(add_another_a_level: 'yes')
      expect(repository.read).to include(add_another_a_level: 'yes')
    end
  end
end
