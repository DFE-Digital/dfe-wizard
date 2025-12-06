require 'active_support/all'
require 'active_model'

module DfE
  # Multi-step form wizard framework using graph-based navigation
  #
  # DfE::Wizard provides a flexible, composable system for building multi-step wizards
  # with conditional branching, state persistence, and validation.
  #
  # ## Architecture
  #
  # The framework is organized into distinct modules:
  #
  # - **Core**: Wizard capabilities (step management, navigation, validation, check-your-answers)
  # - **Validators**: Validation logic for steps and paths
  # - **StateStore**: Persistence adapters (session, redis, memory, etc.)
  # - **StepsProcessor**: Flow implementations (graph-based navigation)
  # - **RouteStrategy**: URL generation strategies
  #
  # ## Quick Start
  #
  #   class MyWizard
  #     include DfE::Wizard
  #
  #     def steps_processor
  #       DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
  #         graph.add_node :name, NameStep
  #         graph.add_node :email, EmailStep
  #         graph.add_node :review, ReviewStep
  #
  #         graph.root :name
  #         graph.add_edge from: :name, to: :email
  #         graph.add_edge from: :email, to: :review
  #
  #         graph.before_next_step { handle_return_to_check_your_answers(:review) }
  #         graph.before_previous_step { handle_back_to_check_your_answers(:review) }
  #       end
  #     end
  #
  #     def route_strategy
  #       DfE::Wizard::RouteStrategy::NamedRoutes.new(namespace: 'my-wizard')
  #     end
  #   end
  #
  # ## Usage
  #
  #   wizard = MyWizard.new(
  #     current_step: :email,
  #     state_store: DfE::Wizard::StateStore::SessionStore.new(session),
  #     current_step_params: params
  #   )
  #
  #   wizard.next_step       # => :review
  #   wizard.path_valid_to?(:review)  # => true/false
  #   wizard.save
  #
  # @since 2.0.0
  module Wizard
    # @!group Core classes
    #
    # Provides the main contract on wizard objects
    #
    module Behaviours
      # Check-your-answers pattern support
      # @api public
      autoload :CheckYourAnswers, 'dfe/wizard/behaviours/check_your_answers'

      # Navigation through wizard steps
      # @api public
      autoload :Navigation, 'dfe/wizard/behaviours/navigation'

      # All state management under wizard
      #
      # @api public
      autoload :StateManagement, 'dfe/wizard/behaviours/state_management'

      # Step lifecycle management
      # @api public
      autoload :StepManagement, 'dfe/wizard/behaviours/step_management'

      # Step and path validation
      # @api public
      autoload :Validation, 'dfe/wizard/behaviours/validation'
    end
    # @!endgroup

    # @!group Core classes

    # Core wizard capabilities - provides the main objects
    #
    # @api public
    module Core
      # Full metadata of the wizard
      # @api public
      autoload :Metadata, 'dfe/wizard/core/metadata'

      # Virtual step for redirecting steps
      #
      autoload :Redirect, 'dfe/wizard/core/redirect'

      # Define a State store to manage all data and business logic
      #
      # @api public
      autoload :StateStore, 'dfe/wizard/core/state_store'

      # Define a step with attributes and validation
      # @api public
      autoload :Step, 'dfe/wizard/core/step'
    end
    # @!endgroup

    # @!group Auto generate Documentation for any wizard
    module Documentation
      autoload :Generator, 'dfe/wizard/documentation/generator'

      module Formatters
        # Generate the documentation in markdown
        autoload :MarkdownFormatter, 'dfe/wizard/documentation/formatters/markdown_formatter'
      end
    end
    # @!endgroup

    # @!group Default operations in every step of a wizard
    #
    # Provide default operations
    #
    module Operations
      autoload :Validate, 'dfe/wizard/operations/validate'
      autoload :Persist, 'dfe/wizard/operations/persist'
    end
    # @!endgroup

    # @!group State Persistence
    # Repository adapters for wizard state persistence
    #
    # All repositories implement a common, minimal interface.
    # Can be extended with new adapters for different backends.
    #
    # @api public
    module Repository
      autoload :Base, 'dfe/wizard/repository/base'
      autoload :InMemory, 'dfe/wizard/repository/in_memory'
      autoload :Session, 'dfe/wizard/repository/session'
      autoload :Redis, 'dfe/wizard/repository/redis'
      autoload :Cache, 'dfe/wizard/repository/cache'
    end
    # @!endgroup

    module Tooling
      # Documentation capabilities
      # @api public
      autoload :DocManagement, 'dfe/wizard/tooling/doc_management'

      # Inspect class to understand the whole wizard management in development
      # @api public
      autoload :Inspect, 'dfe/wizard/tooling/inspect'

      # Logging capabilities
      # @api public
      autoload :LogManagement, 'dfe/wizard/tooling/log_management'
    end

    # @!group Step Operators
    #
    # Step operator to handle action config at any step of the wizard
    #
    module StepsOperator
      autoload :Builder, 'dfe/wizard/steps_operator/builder'
    end
    # @!endgroup

    # @!group Step Processors

    # Step processors handle wizard flow and navigation
    #
    # Determines the next/previous step based on wizard state.
    # Can be extended with new flow implementations.
    #
    # @api public
    module StepsProcessor
      # Graph-based step processor
      # @api public
      autoload :Graph, 'dfe/wizard/steps_processor/graph'
    end

    # @!endgroup
    # @!group Route Strategies

    # Route strategy adapters for URL generation
    #
    # Generates URLs for wizard steps.
    # Can be extended with new strategies for different routing patterns.
    #
    # @api public
    module RouteStrategy
      # Named routes strategy using Rails routes
      # @api public
      autoload :NamedRoutes, 'dfe/wizard/route_strategy/named_routes'

      # Dynamic routes strategy with custom path builder
      # @api public
      autoload :DynamicRoutes, 'dfe/wizard/route_strategy/dynamic_routes'

      # Configurable route strategy with DSL
      # @api public
      autoload :ConfigurableRoutes, 'dfe/wizard/route_strategy/configurable_routes'
    end

    module Logging
      autoload :Logger, 'dfe/wizard/logging/logger'
      autoload :NullLogger, 'dfe/wizard/logging/null_logger'
    end

    module Test
      autoload :RSpecMatchers, 'dfe/wizard/test/r_spec_matchers'
    end

    # @!endgroup
    # @!group Supporting Classes

    autoload :Version, 'dfe/wizard/version'

    # @!endgroup
    # @!group Main API

    include Core
    include Tooling
    include Tooling::LogManagement
    include Tooling::DocManagement
    include Logging

    include Behaviours::Navigation
    include Behaviours::Validation
    include Behaviours::StepManagement
    include Behaviours::StateManagement
    include Behaviours::CheckYourAnswers

    # Initializes a new wizard instance
    #
    # @param current_step [Symbol, nil] Name of the current step
    # @param current_step_params [Hash] Parameters for the current step (typically from request)
    # @param state_store [DfE::Wizard::StateStore] State persistence adapter
    #
    # @example
    #   wizard = MyWizard.new(
    #     current_step: :email,
    #     current_step_params: params,
    #     state_store: MyStateStore.new(
    #       repository: DfE::Wizard::Repository::InMemory.new,
    #     ),
    #   )
    #
    # @return [self]
    def initialize(state_store:, current_step: nil, current_step_params: {})
      @current_step_name = current_step&.to_sym
      @current_step_params = current_step_params
      @state_store = state_store

      after_initialize
    end

    # Callback hook executed after wizard initialization
    #
    # Automatically triggers attribute method generation on the state_store
    # if enabled via `define_step_attributes_methods?`.
    #
    # This ensures all step attribute reader methods are available immediately
    # after wizard instantiation without requiring manual setup.
    #
    # @return [void]
    #
    # @example Automatic generation during initialization
    #   wizard = DBSCheckWizard.new(
    #     current_step: :personal_details,
    #     state_store: state_store
    #   )
    #
    #   # Methods already available thanks to after_initialize
    #   state_store.first_name  # => "Sarah"
    #   state_store.email       # => "sarah@example.com"
    #
    # @note Called automatically by initialize - no manual invocation needed
    # @note Can be overridden in subclasses to customize initialization behavior
    #
    # @api public
    def after_initialize
      define_step_attributes_in_state_store
    end

    def define_step_attributes_in_state_store
      @state_store.step_definitions = step_definitions
      @state_store.attribute_names = attribute_names
    end

    # The current step being displayed
    # @return [Symbol, nil]
    attr_accessor :current_step_name

    # The state store instance
    # @return [DfE::Wizard::StateStore::Base]
    attr_accessor :state_store

    # @!endgroup
    # @!group Extension Points

    # Returns the steps processor for this wizard
    #
    # Must be implemented by subclasses.
    #
    # @return [DfE::Wizard::StepsProcessor::Graph]
    # @raise [NotImplementedError]
    #
    # @example
    #   def steps_processor
    #     DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
    #       graph.add_node :step1, Step1
    #       graph.root :step1
    #     end
    #   end
    def steps_processor
      raise NotImplementedError, 'Subclass must implement #steps_processor'
    end

    # Returns the route strategy for this wizard
    #
    # Must be implemented by subclasses.
    #
    # @return [DfE::Wizard::RouteStrategy::NamedRoutes, DfE::Wizard::RouteStrategy::DynamicRoutes]
    # @raise [NotImplementedError]
    #
    # @example
    #   def route_strategy
    #     DfE::Wizard::RouteStrategy::NamedRoutes.new(namespace: 'my-wizard')
    #   end
    def route_strategy
      raise NotImplementedError, 'Subclass must implement #route_strategy'
    end
    # @!endgroup
  end
end
