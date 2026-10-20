RSpec.describe DfE::Wizard::Changeset do
  include SubWizardSpecHelpers

  # A plain Graph wizard: the changeset works without change journeys.
  def wizard_on(repository, store: SubWizardSpecStore.new(repository:))
    build_wizard(store:) do |g|
      parent_nodes(g)
      visa_nodes(g)
    end
  end

  repositories = {
    'InMemory' => -> { DfE::Wizard::Repository::InMemory.new },
    'Cache' => -> { DfE::Wizard::Repository::Cache.new(cache: ActiveSupport::Cache::MemoryStore.new, key: 'cs') },
    'Session' => -> { DfE::Wizard::Repository::Session.new(session: {}, state_key: 'k1') },
    'Redis' => -> { DfE::Wizard::Repository::Redis.new(redis: MockRedis.new, key: 'cs', state_key: 'k1') },
  }

  repositories.each do |name, build|
    context "on #{name}" do
      let(:wizard) { wizard_on(build.call) }

      it 'stores and reads back the journey state' do
        wizard.changeset.journey = { unit: :visa, shown: [:funding], snapshot: { funding: 'fee' } }

        expect(wizard.changeset.journey).to eq(unit: 'visa', shown: ['funding'], snapshot: { funding: 'fee' })
      end

      it 'replaces the whole state, keeping no field of the old one' do
        wizard.changeset.journey = { unit: :visa, shown: [], snapshot: { funding: 'fee', student_visa: true } }
        wizard.changeset.journey = { unit: :funding, shown: [], snapshot: { funding: 'salary' } }

        expect(wizard.changeset.journey[:snapshot]).to eq(funding: 'salary')
      end

      it 'keeps the key out of raw_data, data and metadata' do
        wizard.state_store.write(funding: 'fee')
        wizard.changeset.journey = { unit: :funding, shown: [], snapshot: {} }

        expect(wizard.raw_data).to eq(steps: { funding: { funding: 'fee' } })
        expect(wizard.all_metadata).to eq({})
        expect(wizard.get_metadata(:_dfe_wizard)).to be_nil
      end

      it 'finds no change for answers read back from storage' do
        wizard.state_store.write(funding: 'fee', student_visa: false)
        snapshot = wizard.changeset.answers

        expect(wizard.changeset.answer_changes_since(snapshot)).to eq([])
      end

      it 'lists changed, added and removed answers in attribute order' do
        wizard.state_store.write(funding: 'fee', student_visa: false)
        snapshot = wizard.changeset.answers
        wizard.state_store.write(funding: 'salary', student_visa: nil, skilled_visa: true)

        expect(wizard.changeset.answer_changes_since(snapshot)).to eq(%i[funding student_visa skilled_visa])
      end
    end
  end

  it 'reads the key as a symbol or a string, the symbol winning' do
    repository = DfE::Wizard::Repository::InMemory.new
    repository.write('_dfe_wizard' => { journey: { unit: 'old' } }, _dfe_wizard: { journey: { unit: 'new' } })

    expect(wizard_on(repository).changeset.journey).to eq(unit: 'new')
  end

  it 'ignores keys that are not answers' do
    wizard = wizard_on(DfE::Wizard::Repository::InMemory.new)
    snapshot = wizard.changeset.answers
    wizard.state_store.write(completed: true, user_id: 3)

    expect(wizard.changeset.answer_changes_since(snapshot)).to eq([])
  end

  it 'reads and writes nothing when built' do
    repository = DfE::Wizard::Repository::InMemory.new
    wizard = wizard_on(repository)
    allow(repository).to receive(:read).and_call_original
    allow(repository).to receive(:write).and_call_original

    wizard.changeset

    expect(repository).not_to have_received(:read)
    expect(repository).not_to have_received(:write)
  end

  it 'raises before writing to a Repository::Model' do
    record = Struct.new(:funding).new('fee')
    repository = DfE::Wizard::Repository::Model.new(record:)
    wizard = wizard_on(repository)
    allow(repository).to receive(:write)

    expect { wizard.changeset.journey = { unit: :funding } }
      .to raise_error(ArgumentError, 'Repository::Model cannot hold a changeset')
    expect(repository).not_to have_received(:write)
  end

  it 'raises for a state store built without a repository' do
    wizard = wizard_on(nil, store: SubWizardSpecStore.new)

    expect { wizard.changeset.journey = { unit: :funding } }
      .to raise_error(ArgumentError, /the state store was built without one/)
  end

  it 'raises when the repository drops the key' do
    dropping = Class.new(DfE::Wizard::Repository::InMemory) do
      def transform_for_write(data)
        data.except(:_dfe_wizard)
      end
    end

    expect { wizard_on(dropping.new).changeset.journey = { unit: :funding } }
      .to raise_error(ArgumentError,
                      'the repository dropped _dfe_wizard; check transform_for_read and transform_for_write')
  end
end
