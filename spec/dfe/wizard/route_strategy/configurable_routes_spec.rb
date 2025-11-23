RSpec.describe DfE::Wizard::RouteStrategy::ConfigurableRoutes do
  let(:wizard) { instance_double('Wizard') }
  let(:url_helpers) { Rails.application.routes.url_helpers }

  before do
    allow(wizard).to receive(:url_helpers).and_return(url_helpers)
  end

  describe '#initialize' do
    it 'accepts namespace and wizard' do
      strategy = described_class.new(namespace: 'test', wizard: wizard)
      expect(strategy).to be_a(described_class)
    end

    it 'accepts configuration block' do
      strategy = described_class.new(namespace: 'test', wizard: wizard) do |config|
        config.map_step :email, to: ->(_w, _o, _h) { '/email' }
      end

      expect(strategy.route?(:email)).to be true
    end

    it 'initializes with empty routes' do
      strategy = described_class.new(namespace: 'test', wizard: wizard)
      expect(strategy.routes).to be_empty
    end

    it 'initializes with empty default_path_arguments' do
      strategy = described_class.new(namespace: 'test', wizard: wizard)
      expect(strategy.default_path_arguments).to eq({})
    end
  end

  describe '#default_path_arguments' do
    let(:strategy) { described_class.new(namespace: 'test', wizard: wizard) }

    it 'can be set and retrieved' do
      args = { provider_code: 'ABC', course_code: '123' }
      strategy.default_path_arguments = args
      expect(strategy.default_path_arguments).to eq(args)
    end

    it 'returns empty hash when not set' do
      expect(strategy.default_path_arguments).to eq({})
    end

    it 'can be set in configuration block' do
      strategy = described_class.new(namespace: 'test', wizard: wizard) do |config|
        config.default_path_arguments = { provider_code: 'XYZ' }
      end

      expect(strategy.default_path_arguments).to eq({ provider_code: 'XYZ' })
    end
  end

  describe '#configure' do
    let(:strategy) { described_class.new(namespace: 'test', wizard: wizard) }

    it 'yields self for configuration' do
      expect { |b| strategy.configure(&b) }.to yield_with_args(strategy)
    end

    it 'can be called after initialization' do
      strategy.configure do |config|
        config.map_step :email, to: ->(_w, _o, _h) { '/email' }
      end

      expect(strategy.route?(:email)).to be true
    end

    it 'returns self for chaining' do
      result = strategy.configure { |c| c.map_step :test, to: ->(_w, _o, _h) { '/test' } }
      expect(result).to eq(strategy)
    end
  end

  describe '#map_step' do
    let(:strategy) { described_class.new(namespace: 'test', wizard: wizard) }

    it 'maps a step to a lambda' do
      route_lambda = ->(_w, _o, _h) { '/custom' }
      strategy.map_step :email, to: route_lambda

      expect(strategy.routes[:email]).to eq(route_lambda)
    end

    it 'maps a step to a method' do
      def custom_route(_wizard, _options, _helpers)
        '/method-route'
      end

      strategy.map_step :email, to: method(:custom_route)
      expect(strategy.route?(:email)).to be true
    end

    it 'accepts symbol keys' do
      strategy.map_step :email, to: ->(_w, _o, _h) { '/email' }
      expect(strategy.route?(:email)).to be true
    end

    it 'converts string keys to symbols' do
      strategy.map_step 'email', to: ->(_w, _o, _h) { '/email' }
      expect(strategy.route?(:email)).to be true
    end

    it 'returns self for chaining' do
      result = strategy.map_step :email, to: ->(_w, _o, _h) { '/email' }
      expect(result).to eq(strategy)
    end

    it 'allows multiple step mappings' do
      strategy.map_step :email, to: ->(_w, _o, _h) { '/email' }
      strategy.map_step :payment, to: ->(_w, _o, _h) { '/payment' }

      expect(strategy.routes.keys).to contain_exactly(:email, :payment)
    end
  end

  describe '#resolve' do
    let(:strategy) do
      described_class.new(namespace: 'personal_information', wizard: wizard)
    end

    context 'with mapped route' do
      before do
        strategy.map_step :email, to: lambda { |_wizard, options, helpers|
          helpers.custom_email_path(**options)
        }

        allow(url_helpers).to receive(:custom_email_path)
          .with(provider_code: 'ABC')
          .and_return('/custom/ABC/email')
      end

      it 'calls the mapped lambda' do
        result = strategy.resolve(step_id: :email, options: { provider_code: 'ABC' })
        expect(result).to eq('/custom/ABC/email')
      end

      it 'passes wizard to the lambda' do
        expect do |probe|
          strategy.map_step :test, to: probe.to_proc
          strategy.resolve(step_id: :test, options: {})
        end.to yield_with_args(wizard, anything, anything)
      end

      it 'passes options to the lambda' do
        expect do |probe|
          strategy.map_step :test, to: probe.to_proc
          strategy.resolve(step_id: :test, options: { foo: 'bar' })
        end.to yield_with_args(anything, hash_including(foo: 'bar'), anything)
      end

      it 'passes url_helpers to the lambda' do
        expect do |probe|
          strategy.map_step :test, to: probe.to_proc
          strategy.resolve(step_id: :test, options: {})
        end.to yield_with_args(anything, anything, url_helpers)
      end
    end

    context 'with default_path_arguments' do
      before do
        strategy.default_path_arguments = {
          provider_code: 'DEFAULT',
          recruitment_cycle_year: 2024,
        }
      end

      it 'merges default arguments with step options' do
        strategy.map_step :email, to: lambda { |_wizard, options, helpers|
          helpers.email_path(**options)
        }

        allow(url_helpers).to receive(:email_path)
          .with(provider_code: 'DEFAULT', recruitment_cycle_year: 2024, user_id: 5)
          .and_return('/email/DEFAULT/2024/5')

        result = strategy.resolve(step_id: :email, options: { user_id: 5 })
        expect(result).to eq('/email/DEFAULT/2024/5')
      end

      it 'allows step options to override defaults' do
        strategy.map_step :email, to: lambda { |_wizard, options, helpers|
          helpers.email_path(**options)
        }

        allow(url_helpers).to receive(:email_path)
          .with(provider_code: 'OVERRIDE', recruitment_cycle_year: 2024)
          .and_return('/email/OVERRIDE/2024')

        result = strategy.resolve(step_id: :email, options: { provider_code: 'OVERRIDE' })
        expect(result).to eq('/email/OVERRIDE/2024')
      end

      context 'with unmapped step' do
        before do
          allow(url_helpers).to receive(:personal_information_nationality_path)
            .with(hash_including(provider_code: 'DEFAULT', recruitment_cycle_year: 2024))
            .and_return('/personal-information/DEFAULT/2024/nationality')
        end

        it 'falls back to NamedRoutes with merged arguments' do
          result = strategy.resolve(step_id: :nationality, options: {})
          expect(result).to eq('/personal-information/DEFAULT/2024/nationality')
        end
      end
    end

    context 'without mapped route' do
      before do
        allow(url_helpers).to receive(:personal_information_nationality_path)
          .with({})
          .and_return('/personal-information/nationality')
      end

      it 'falls back to parent NamedRoutes behavior' do
        result = strategy.resolve(step_id: :nationality, options: {})
        expect(result).to eq('/personal-information/nationality')
      end
    end

    context 'with method as callable' do
      def email_route(_wizard, options, helpers)
        helpers.method_email_path(**options)
      end

      before do
        strategy.map_step :email, to: method(:email_route)
        allow(url_helpers).to receive(:method_email_path)
          .with(user_id: 10)
          .and_return('/method/email/10')
      end

      it 'calls the method' do
        result = strategy.resolve(step_id: :email, options: { user_id: 10 })
        expect(result).to eq('/method/email/10')
      end
    end
  end

  describe '#routes' do
    let(:strategy) { described_class.new(namespace: 'test', wizard: wizard) }

    it 'returns a copy of routes hash' do
      strategy.map_step :email, to: ->(_w, _o, _h) { '/email' }
      routes = strategy.routes

      expect(routes).to eq({ email: strategy.routes[:email] })
      expect(routes.object_id).not_to eq(strategy.routes.object_id)
    end

    it 'does not allow external modification' do
      strategy.map_step :email, to: ->(_w, _o, _h) { '/email' }
      routes = strategy.routes
      routes[:payment] = ->(_w, _o, _h) { '/payment' }

      expect(strategy.route?(:payment)).to be false
    end
  end

  describe '#route?' do
    let(:strategy) { described_class.new(namespace: 'test', wizard: wizard) }

    it 'returns true for mapped routes' do
      strategy.map_step :email, to: ->(_w, _o, _h) { '/email' }
      expect(strategy.route?(:email)).to be true
    end

    it 'returns false for unmapped routes' do
      expect(strategy.route?(:payment)).to be false
    end

    it 'accepts string keys' do
      strategy.map_step :email, to: ->(_w, _o, _h) { '/email' }
      expect(strategy.route?('email')).to be true
    end
  end

  describe '#clear_routes' do
    let(:strategy) { described_class.new(namespace: 'test', wizard: wizard) }

    it 'removes all mapped routes' do
      strategy.map_step :email, to: ->(_w, _o, _h) { '/email' }
      strategy.map_step :payment, to: ->(_w, _o, _h) { '/payment' }

      strategy.clear_routes

      expect(strategy.routes).to be_empty
      expect(strategy.route?(:email)).to be false
      expect(strategy.route?(:payment)).to be false
    end
  end

  describe 'integration example' do
    let(:course) { double('Course', provider_code: 'ABC', course_code: '123', recruitment_cycle_year: 2024) }
    let(:wizard) { double('Wizard', course: course, url_helpers: url_helpers) }

    it 'works with real-world wizard configuration' do
      strategy = described_class.new(namespace: 'a_levels_requirements', wizard: wizard) do |config|
        config.default_path_arguments = {
          provider_code: wizard.course.provider_code,
          recruitment_cycle_year: wizard.course.recruitment_cycle_year,
          course_code: wizard.course.course_code,
        }

        config.map_step :course_edit, to: lambda { |_wizard, options, helpers|
          helpers.edit_course_path(**options)
        }
      end

      allow(url_helpers).to receive(:a_levels_requirements_what_a_level_is_required_path)
        .with(hash_including(provider_code: 'ABC', recruitment_cycle_year: 2024, course_code: '123'))
        .and_return('/publish/organisations/ABC/2024/courses/123/a-levels/what-a-level-is-required')

      allow(url_helpers).to receive(:edit_course_path)
        .with(hash_including(provider_code: 'ABC', recruitment_cycle_year: 2024, course_code: '123'))
        .and_return('/publish/organisations/ABC/2024/courses/123/edit')

      result = strategy.resolve(step_id: :what_a_level_is_required, options: {})
      expect(result).to eq('/publish/organisations/ABC/2024/courses/123/a-levels/what-a-level-is-required')

      result = strategy.resolve(step_id: :course_edit, options: {})
      expect(result).to eq('/publish/organisations/ABC/2024/courses/123/edit')
    end
  end
end
