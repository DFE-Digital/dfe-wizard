RSpec.describe DfE::Wizard::Repository::Model do
  let(:user) do
    FactoryBot.create(
      :user,
      email: 'test@example.com',
      first_name: 'John',
      last_name: 'Doe',
      date_of_birth: '1990-01-01',
    )
  end

  subject(:repository) do
    described_class.new(record: user)
  end

  describe '#initialize' do
    it 'requires record' do
      expect {
        described_class.new(record: nil)
      }.to raise_error(ArgumentError, 'record cannot be nil')
    end
  end

  describe '#read' do
    it 'returns all model attributes' do
      data = repository.read

      expect(data).to include(
        email: 'test@example.com',
        first_name: 'John',
        last_name: 'Doe',
        date_of_birth: Date.parse('1990-01-01'),
      )
    end

    it 'includes Rails internal columns by default' do
      data = repository.read

      expect(data).to have_key(:id)
      expect(data).to have_key(:created_at)
      expect(data).to have_key(:updated_at)
    end

    it 'includes nil values' do
      user.update!(first_name: nil, last_name: nil)
      data = repository.read

      expect(data).to have_key(:first_name)
      expect(data[:first_name]).to be_nil
      expect(data).to have_key(:last_name)
      expect(data[:last_name]).to be_nil
    end

    it 'symbolizes keys' do
      data = repository.read
      expect(data.keys).to all(be_a(Symbol))
    end

    it 'reflects current database state' do
      user.update_columns(first_name: 'Changed')

      data = repository.read
      expect(data[:first_name]).to eq('Changed')
    end
  end

  describe '#write' do
    it 'updates model attributes' do
      repository.write({ first_name: 'Jane' })

      expect(user.first_name).to eq('Jane')
    end

    it 'persists changes to database' do
      repository.write({ first_name: 'Jane' })

      user.reload
      expect(user.first_name).to eq('Jane')
    end

    it 'persists changes visible to new instance' do
      repository.write({ first_name: 'Jane', last_name: 'Smith' })

      fresh_user = User.find(user.id)
      expect(fresh_user.first_name).to eq('Jane')
      expect(fresh_user.last_name).to eq('Smith')
    end

    it 'updates multiple attributes' do
      repository.write({
                         first_name: 'Jane',
                         last_name: 'Smith',
                         phone: '1234567890',
                       })

      user.reload
      expect(user.first_name).to eq('Jane')
      expect(user.last_name).to eq('Smith')
      expect(user.phone).to eq('1234567890')
    end

    it 'calls save! on the record' do
      expect(user).to receive(:save!).and_call_original

      repository.write({ first_name: 'Jane' })
    end

    it 'silently ignores non-existent attributes' do
      expect {
        repository.write({
                           first_name: 'Jane',
                           nonexistent: 'value',
                           another_fake: 'ignored',
                         })
      }.not_to raise_error

      user.reload
      expect(user.first_name).to eq('Jane')
    end

    it 'merges updates across multiple writes' do
      repository.write({ first_name: 'Jane' })
      repository.write({ last_name: 'Smith' })
      repository.write({ phone: '1234567890' })

      user.reload
      expect(user.first_name).to eq('Jane')
      expect(user.last_name).to eq('Smith')
      expect(user.phone).to eq('1234567890')
    end

    it 'handles nil values correctly' do
      repository.write({ phone: '1234567890' })
      user.reload
      expect(user.phone).to eq('1234567890')

      repository.write({ phone: nil })
      user.reload
      expect(user.phone).to be_nil
    end

    context 'with validation errors' do
      it 'raises error if save fails' do
        expect {
          repository.write({ email: nil })
        }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'does not persist invalid data' do
        original_email = user.email

        expect {
          repository.write({ email: nil })
        }.to raise_error(ActiveRecord::RecordInvalid)

        user.reload
        expect(user.email).to eq(original_email)
      end
    end
  end

  describe '#clear' do
    it 'raises NotImplementedError' do
      expect {
        repository.clear
      }.to raise_error(NotImplementedError, /does not support clear operation/)
    end

    it 'explains why clear is not supported' do
      expect {
        repository.clear
      }.to raise_error(NotImplementedError, /business rules/)
    end
  end

  describe '#exists?' do
    it 'returns false for new unpersisted record' do
      new_user = User.new(email: 'new@example.com')
      repo = described_class.new(record: new_user)

      expect(repo.exists?).to be false
    end

    it 'returns false when all readable attributes are nil' do
      limited_repo_class = Class.new(described_class) do
        def readable_attributes
          %i[first_name last_name]
        end
      end

      limited_repo = limited_repo_class.new(record: user)

      user.update!(
        first_name: nil,
        last_name: nil,
      )

      expect(limited_repo.exists?).to be false
    end

    it 'returns true when any attribute has value' do
      expect(repository.exists?).to be true
    end

    it 'returns true even if only one attribute has value' do
      user.update!(
        first_name: nil,
        last_name: nil,
        date_of_birth: nil,
        phone: '1234567890',
        bio: nil,
      )

      expect(repository.exists?).to be true
    end
  end

  describe '#model' do
    it 'returns the underlying record' do
      expect(repository.model).to eq(user)
    end

    it 'returns the actual ActiveRecord instance' do
      expect(repository.model).to be_a(User)
      expect(repository.model.id).to eq(user.id)
    end
  end

  describe 'excluded_columns' do
    context 'default behavior (no exclusions)' do
      it 'returns all columns including internals' do
        data = repository.read

        expect(data).to have_key(:id)
        expect(data).to have_key(:created_at)
        expect(data).to have_key(:updated_at)
      end
    end

    context 'with custom exclusions' do
      let(:custom_repository_class) do
        Class.new(described_class) do
          protected

          def excluded_columns
            %i[id created_at updated_at]
          end
        end
      end

      subject(:repository) { custom_repository_class.new(record: user) }

      it 'excludes specified columns from read' do
        data = repository.read

        expect(data).not_to have_key(:id)
        expect(data).not_to have_key(:created_at)
        expect(data).not_to have_key(:updated_at)
        expect(data).to have_key(:first_name)
        expect(data).to have_key(:email)
      end
    end

    context 'excluding sensitive columns' do
      let(:user_with_secrets) do
        User.create!(
          email: 'secure@example.com',
          first_name: 'John',
          password_digest: 'encrypted',
          api_token: 'secret123',
          secret_key: 'very_secret',
        )
      end

      let(:secure_repository_class) do
        Class.new(described_class) do
          protected

          def excluded_columns
            %i[password_digest api_token secret_key]
          end
        end
      end

      subject(:repository) { secure_repository_class.new(record: user_with_secrets) }

      it 'excludes sensitive columns from read' do
        data = repository.read

        expect(data).not_to have_key(:password_digest)
        expect(data).not_to have_key(:api_token)
        expect(data).not_to have_key(:secret_key)
        expect(data).to have_key(:first_name)
        expect(data).to have_key(:email)
      end
    end
  end

  describe 'writable_attributes' do
    context 'with read-only attributes' do
      let(:readonly_repository_class) do
        Class.new(described_class) do
          protected

          def readable_attributes
            %i[first_name last_name email created_at]
          end

          def writable_attributes
            %i[first_name last_name]
          end
        end
      end

      subject(:repository) { readonly_repository_class.new(record: user) }

      it 'includes read-only attributes in read' do
        data = repository.read

        expect(data).to have_key(:created_at)
        expect(data).to have_key(:email)
      end

      it 'prevents writing to read-only attributes' do
        repository.write({
                           first_name: 'Jane',
                           email: 'changed@example.com',
                         })

        user.reload
        expect(user.first_name).to eq('Jane')
        expect(user.email).to eq('test@example.com')
      end

      it 'allows writing to writable attributes' do
        repository.write({
                           first_name: 'Jane',
                           last_name: 'Smith',
                         })

        user.reload
        expect(user.first_name).to eq('Jane')
        expect(user.last_name).to eq('Smith')
      end
    end
  end

  describe 'attribute transformation' do
    let(:custom_repository_class) do
      Class.new(described_class) do
        protected

        def transform_for_read(data)
          data.transform_keys do |key|
            case key
            when :email then :email_address
            when :date_of_birth then :dob
            when :first_name then :given_name
            when :last_name then :family_name
            else key
            end
          end
        end

        def transform_for_write(data)
          data.transform_keys do |key|
            case key
            when :email_address then :email
            when :dob then :date_of_birth
            when :given_name then :first_name
            when :family_name then :last_name
            else key
            end
          end
        end
      end
    end

    subject(:repository) { custom_repository_class.new(record: user) }

    describe '#read' do
      it 'transforms attribute names on read' do
        data = repository.read

        expect(data).to have_key(:email_address)
        expect(data).to have_key(:dob)
        expect(data).to have_key(:given_name)
        expect(data).to have_key(:family_name)

        expect(data).not_to have_key(:email)
        expect(data).not_to have_key(:date_of_birth)
        expect(data).not_to have_key(:first_name)
        expect(data).not_to have_key(:last_name)
      end

      it 'returns correct values with transformed keys' do
        data = repository.read

        expect(data[:email_address]).to eq('test@example.com')
        expect(data[:given_name]).to eq('John')
        expect(data[:family_name]).to eq('Doe')
        expect(data[:dob]).to eq(Date.parse('1990-01-01'))
      end
    end

    describe '#write' do
      it 'transforms attribute names on write' do
        repository.write({
                           email_address: 'new@example.com',
                           dob: '2000-01-01',
                           given_name: 'Jane',
                           family_name: 'Smith',
                         })

        user.reload
        expect(user.email).to eq('new@example.com')
        expect(user.date_of_birth).to eq(Date.parse('2000-01-01'))
        expect(user.first_name).to eq('Jane')
        expect(user.last_name).to eq('Smith')
      end

      it 'persists transformed attributes to database' do
        repository.write({
                           email_address: 'transformed@example.com',
                           given_name: 'Transformed',
                         })

        fresh_user = User.find(user.id)
        expect(fresh_user.email).to eq('transformed@example.com')
        expect(fresh_user.first_name).to eq('Transformed')
      end
    end
  end

  describe 'custom readable_attributes' do
    let(:limited_repository_class) do
      Class.new(described_class) do
        protected

        def readable_attributes
          %i[first_name last_name email]
        end
      end
    end

    subject(:repository) { limited_repository_class.new(record: user) }

    it 'only returns specified attributes' do
      data = repository.read

      expect(data.keys).to contain_exactly(:first_name, :last_name, :email)
      expect(data).not_to have_key(:date_of_birth)
      expect(data).not_to have_key(:phone)
    end
  end

  describe 'complex integration scenarios' do
    it 'handles full wizard flow with persistence' do
      repository.write({
                         first_name: 'Alice',
                         last_name: 'Johnson',
                       })

      expect(user.reload.first_name).to eq('Alice')

      repository.write({
                         phone: '5551234567',
                         email: 'alice@example.com',
                       })

      user.reload
      expect(user.first_name).to eq('Alice')
      expect(user.last_name).to eq('Johnson')
      expect(user.phone).to eq('5551234567')
      expect(user.email).to eq('alice@example.com')

      repository.write({
                         date_of_birth: '1985-03-15',
                         bio: 'Software engineer',
                       })

      fresh_user = User.find(user.id)
      expect(fresh_user.first_name).to eq('Alice')
      expect(fresh_user.last_name).to eq('Johnson')
      expect(fresh_user.phone).to eq('5551234567')
      expect(fresh_user.email).to eq('alice@example.com')
      expect(fresh_user.date_of_birth).to eq(Date.parse('1985-03-15'))
      expect(fresh_user.bio).to eq('Software engineer')
    end

    it 'handles concurrent repository instances correctly' do
      repo1 = described_class.new(record: user)
      repo2 = described_class.new(record: user)

      repo1.write({ first_name: 'Repo1' })

      data = repo2.read
      expect(data[:first_name]).to eq('Repo1')

      repo2.write({ last_name: 'Repo2' })

      user.reload
      expect(user.first_name).to eq('Repo1')
      expect(user.last_name).to eq('Repo2')
    end
  end
end
