RSpec.describe DfE::Wizard::Changeset do
  include SubWizardSpecHelpers

  # A plain Graph wizard: the changeset works without change journeys.
  def wizard_on(repository, store: SubWizardSpecStore.new(repository:))
    build_wizard(store:) do |g|
      parent_nodes(g)
      visa_nodes(g)
    end
  end

  # A wizard with the visa edges, so full_path follows funding.
  def wizard_with_path(repository)
    build_wizard(store: SubWizardSpecStore.new(repository:)) do |g|
      parent_nodes(g)
      visa_nodes(g)
      parent_edges(g)
      visa_edges(g)
    end
  end

  seeded_at = Time.utc(2026, 10, 9, 12, 0, 0, 123_456)

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

      it 'seeds the answers and the edit metadata' do
        wizard.changeset.seed!({ funding: 'fee', student_visa: false }, updated_at: seeded_at)

        expect(wizard.changeset.seed).to eq(funding: 'fee', student_visa: false)
        expect(wizard.changeset.seed_updated_at).to eq('2026-10-09T12:00:00.123456Z')
        expect(wizard.changeset.answers).to eq(funding: 'fee', student_visa: false)
        expect(wizard.changeset).to be_edit
      end

      it 'finds no diff for seeded answers read back from storage' do
        wizard.changeset.seed!({ funding: 'fee', student_visa: false })

        expect(wizard.changeset.diff).to eq({})
        expect(wizard.changeset).not_to be_diff
      end

      it 'discards its answers and metadata' do
        wizard.changeset.seed!({ funding: 'fee' })
        wizard.changeset.discard!

        expect(wizard.state_store.read).to eq({})
      end
    end

    context "diff on #{name}" do
      let(:wizard) { wizard_with_path(build.call) }

      it 'lists answers on the path that differ from the seed, leaving out answers off the path' do
        wizard.changeset.seed!({ funding: 'fee', student_visa: false })
        wizard.state_store.write(funding: 'salary', skilled_visa: true)

        expect(wizard.changeset.diff).to eq(funding: 'salary', skilled_visa: true)
        expect(wizard.changeset).to be_diff
      end
    end
  end

  describe '#diff' do
    { 'InMemory' => -> { DfE::Wizard::Repository::InMemory.new },
      'Cache' => -> { DfE::Wizard::Repository::Cache.new(cache: ActiveSupport::Cache::MemoryStore.new, key: 'cs') } }
      .each do |name, build|
      it "returns an answer that is not plain JSON as the store holds it on #{name}" do
        wizard = wizard_with_path(build.call)
        wizard.changeset.seed!({ funding: 'fee', student_visa: Date.new(2027, 1, 15) })
        wizard.state_store.write(student_visa: Date.new(2027, 2, 1))

        expect(wizard.changeset.diff).to eq(student_visa: Date.new(2027, 2, 1))
      end

      it "finds no diff for an unchanged answer that is not plain JSON on #{name}" do
        wizard = wizard_with_path(build.call)
        wizard.changeset.seed!({ funding: 'fee', student_visa: Date.new(2027, 1, 15) })

        expect(wizard.changeset.diff).to eq({})
      end

      it "finds a Time answer changed within the same second on #{name}" do
        wizard = wizard_with_path(build.call)
        wizard.changeset.seed!({ funding: 'fee', student_visa: seeded_at })
        wizard.state_store.write(student_visa: seeded_at + 0.5)

        expect(wizard.changeset.diff).to eq(student_visa: seeded_at + 0.5)
      end

      it "finds no diff for a Time answer at the same instant in another zone on #{name}" do
        wizard = wizard_with_path(build.call)
        wizard.changeset.seed!({ funding: 'fee', student_visa: seeded_at })
        wizard.state_store.write(student_visa: seeded_at.getlocal('+01:00'))

        expect(wizard.changeset.diff).to eq({})
      end
    end
  end

  describe '#seed!' do
    it 'raises when the store holds data, before writing' do
      wizard = wizard_on(DfE::Wizard::Repository::InMemory.new)
      wizard.state_store.write(funding: 'fee')

      expect { wizard.changeset.seed!({ funding: 'salary' }) }.to raise_error(ArgumentError, /not empty/)
      expect(wizard.state_store.read).to eq(funding: 'fee')
    end

    it 'raises before writing to a Repository::Model' do
      repository = DfE::Wizard::Repository::Model.new(record: Struct.new(:funding).new('fee'))
      wizard = wizard_on(repository)
      allow(repository).to receive_messages(read: {}, write: nil)

      expect { wizard.changeset.seed!({ funding: 'fee' }) }
        .to raise_error(ArgumentError, 'Repository::Model cannot hold a changeset')
      expect(repository).not_to have_received(:write)
    end
  end

  describe '#stale?' do
    let(:wizard) { wizard_on(DfE::Wizard::Repository::InMemory.new) }
    let(:record_at) { ->(time) { Struct.new(:updated_at).new(time) } }

    it 'is false when nothing is seeded' do
      expect(wizard.changeset.stale?(record_at.call(nil))).to be(false)
    end

    it 'is false when updated_at is the seeded one, to the microsecond' do
      wizard.changeset.seed!({ funding: 'fee' }, updated_at: seeded_at)

      expect(wizard.changeset.stale?(record_at.call(seeded_at))).to be(false)
    end

    it 'is true when updated_at moved' do
      wizard.changeset.seed!({ funding: 'fee' }, updated_at: seeded_at)

      expect(wizard.changeset.stale?(record_at.call(seeded_at + Rational(1, 1_000_000)))).to be(true)
    end

    it 'is true when updated_at is nil' do
      wizard.changeset.seed!({ funding: 'fee' }, updated_at: seeded_at)

      expect(wizard.changeset.stale?(record_at.call(nil))).to be(true)
    end

    it 'is false for a record with no updated_at, seeded or now' do
      wizard.changeset.seed!({ funding: 'fee' }, updated_at: nil)

      expect(wizard.changeset.stale?(record_at.call(nil))).to be(false)
    end

    it 'is false for the same updated_at in another zone' do
      wizard.changeset.seed!({ funding: 'fee' }, updated_at: seeded_at.getlocal('+01:00'))

      expect(wizard.changeset.stale?(record_at.call(seeded_at))).to be(false)
    end
  end

  describe '#discard!' do
    it 'keeps the other state_keys of a Session' do
      session = {}
      other = DfE::Wizard::Repository::Session.new(session:, state_key: 'k2')
      other.write(funding: 'salary')
      wizard = wizard_on(DfE::Wizard::Repository::Session.new(session:, state_key: 'k1'))
      wizard.changeset.seed!({ funding: 'fee' })

      wizard.changeset.discard!

      expect(other.read[:funding]).to eq('salary')
    end

    it 'keeps the other state_keys of a Redis key' do
      redis = MockRedis.new
      other = DfE::Wizard::Repository::Redis.new(redis:, key: 'cs', state_key: 'k2')
      other.write(funding: 'salary')
      wizard = wizard_on(DfE::Wizard::Repository::Redis.new(redis:, key: 'cs', state_key: 'k1'))
      wizard.changeset.seed!({ funding: 'fee' })

      wizard.changeset.discard!

      expect(other.read).to eq(funding: 'salary')
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
