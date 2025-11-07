# frozen_string_literal: true

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
  #     def initialize(current_step:, state_store:, step_params: {})
  #       super
  #     end
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
  #     step_params: params
  #   )
  #
  #   wizard.next_step       # => :review
  #   wizard.path_valid_to?(:review)  # => true/false
  #   wizard.save
  #
  # @since 2.0.0
  module Wizard
    # @!group Core Modules

    # Core wizard capabilities - provides the main contract for wizard behavior
    #
    # Includes:
    # - StepManagement: Step lookup, instantiation, attribute extraction
    # - Navigation: Next/previous step calculation, path traversal
    # - Validation: Step and path validation
    # - CheckYourAnswers: Return-to-review and edit mode handling
    #
    # @api public
    module Core
      # Auto generated documentation management
      # @api public
      autoload :Documentation, 'dfe/wizard/core/documentation'

      # State store lifecycle management
      # @api public
      autoload :StateManagement, 'dfe/wizard/core/state_management'

      # Step lifecycle management
      # @api public
      autoload :StepManagement, 'dfe/wizard/core/step_management'

      # Navigation through wizard steps
      # @api public
      autoload :Navigation, 'dfe/wizard/core/navigation'

      # Step and path validation
      # @api public
      autoload :Validation, 'dfe/wizard/core/validation'

      # Check-your-answers pattern support
      # @api public
      autoload :CheckYourAnswers, 'dfe/wizard/core/check_your_answers'
    end

    # @!endgroup
    # @!group Validators

    # Validation logic for steps and paths
    #
    # Pure, stateless validators that evaluate step and path validity on each call.
    # No caching or state is maintained.
    #
    # @api public
    module Validators
      # Immutable value object representing validation result
      # @api public
      autoload :ValidationResult, 'dfe/wizard/validators/validation_result'

      # Validates individual wizard steps
      # @api public
      autoload :StepValidator, 'dfe/wizard/validators/step_validator'

      # Validates paths through the wizard
      # @api public
      autoload :PathValidator, 'dfe/wizard/validators/path_validator'
    end

    # @!endgroup
    # @!group State Persistence

    # State store adapters for persisting wizard data
    #
    # All stores implement a common interface.
    # Can be extended with new adapters for different backends.
    #
    # @api public
    module StateStore
      # Abstract base class defining the StateStore contract
      # @api public
      autoload :Base, 'dfe/wizard/state_store/base'

      # Session-based state store
      # @api public
      autoload :SessionStore, 'dfe/wizard/state_store/session_store'

      # Redis-based state store
      # @api public
      autoload :RedisStore, 'dfe/wizard/state_store/redis_store'

      # In-memory state store (testing only)
      # @api public
      autoload :MemoryStore, 'dfe/wizard/state_store/memory_store'
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

    module Documentation
      autoload :GraphRenderer, 'dfe/wizard/documentation/graph_renderer'
      autoload :Styles, 'dfe/wizard/documentation/styles'
    end

    # @!endgroup
    # @!group Supporting Classes

    autoload :Step, 'dfe/wizard/step'
    autoload :Base, 'dfe/wizard/base'

    autoload :Version, 'dfe/wizard/version'

    # @!endgroup
    # @!group Main API

    # Include all core modules
    include Core::CheckYourAnswers
    include Core::Documentation
    include Core::Navigation
    include Core::StateManagement
    include Core::StepManagement
    include Core::Validation

    # Initializes a new wizard instance
    #
    # @param current_step [Symbol, nil] Name of the current step
    # @param state_store [DfE::Wizard::StateStore::Base] State persistence adapter
    # @param step_params [Hash] Parameters for the current step (typically from request)
    #
    # @example
    #   wizard = MyWizard.new(
    #     current_step: :email,
    #     state_store: DfE::Wizard::StateStore::SessionStore.new(session),
    #     step_params: params
    #   )
    #
    # @return [self]
    def initialize(current_step:, state_store:, step_params: {})
      @current_step_name = current_step&.to_sym
      @state_store = state_store
      @step_params = step_params
    end

    # The current step being displayed
    # @return [Symbol, nil]
    attr_reader :current_step_name

    # The state store instance
    # @return [DfE::Wizard::StateStore::Base]
    attr_reader :state_store

    # Parameters for the current step (from request)
    # @return [Hash]
    attr_reader :step_params

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

    # Create and cache the step validator
    # The step validator evaluates individual steps:
    # - Is this step visited (step processor visited and has data)?
    # - Is this step valid (passes validation)?
    # - What are the validation errors?
    #
    # Used internally by validation methods like {#step_valid?} and {#step_visited?}.
    #
    # Pure validator with no state - evaluates fresh on each call.
    # Instantiated once per wizard and cached.
    #
    # Can be overridden to use a custom validator implementation.
    #
    # @return [DfE::Wizard::Validators::StepValidator]
    #
    # @example Use default validator
    #   wizard.step_valid?(:email)  # Uses this validator internally
    #
    # @example Override with custom validator
    #   class MyWizard
    #     include DfE::Wizard
    #
    #     def step_validator
    #       @step_validator ||= MyCustomStepValidator.new(self)
    #     end
    #   end
    #
    # @api public
    def step_validator
      @step_validator ||= Validators::StepValidator.new(self)
    end

    # Create and cache the path validator
    #
    # The path validator evaluates sequences of steps:
    # - Are all steps up to a target visited?
    # - Are all steps up to a target valid?
    # - What's the first invalid step?
    # - What's the first unvisited step?
    #
    # Uses the {#step_validator} to validate individual steps.
    # Used internally by validation methods like {#path_complete_to?},
    # {#path_valid_to?}, and {#validated_path}.
    #
    # Pure validator with no state - evaluates fresh on each call.
    # Instantiated once per wizard and cached.
    #
    # Can be overridden to use a custom validator implementation.
    #
    # @return [DfE::Wizard::Validators::PathValidator]
    #
    # @example Use default validator
    #   wizard.path_complete_to?(:review)  # Uses this validator internally
    #
    # @example Override with custom validator
    #   class MyWizard
    #     include DfE::Wizard
    #
    #     def path_validator
    #       @path_validator ||= MyCustomPathValidator.new(self, step_validator)
    #     end
    #   end
    #
    # @api public
    def path_validator
      @path_validator ||= Validators::PathValidator.new(self, step_validator)
    end

    # @!endgroup
  end
end
