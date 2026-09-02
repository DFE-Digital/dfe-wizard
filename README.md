# DfE::Wizard

[![Ruby](https://github.com/DFE-Digital/dfe-wizard/actions/workflows/main.yml/badge.svg)](https://github.com/DFE-Digital/dfe-wizard/actions/workflows/main.yml)

A multi-step form framework for Ruby on Rails applications.

**Version**: 1.0.0

### Requirements

| | Supported |
|---|---|
| Ruby | 3.2, 3.3, 3.4 |
| Rails | 7.1, 7.2, 8.0, 8.1 |

Every combination above is exercised by CI. See [RELEASING.md](RELEASING.md)
for how to add a version.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Getting Started](#getting-started)
4. [Core Concepts](#core-concepts)
5. [Data Flow](#data-flow)
6. [Navigation](#navigation)
7. [Conditional Branching](#conditional-branching)
8. [Check Your Answers](#check-your-answers)
9. [Step Operators](#step-operators)
10. [Testing](#testing)
11. [Auto-generated Documentation](#auto-generated-documentation)
12. [In Depth: Repositories](#in-depth-repositories)
13. [In Depth: Steps](#in-depth-steps)
14. [In Depth: Conditional Edges](#in-depth-conditional-edges)
15. [In Depth: Route Strategies](#in-depth-route-strategies)
16. [Advanced: Custom Implementations](#advanced-custom-implementations)
17. [Examples](#examples)
18. [Troubleshooting](#troubleshooting)

---

## Introduction

DfE::Wizard helps you build multi-step forms (wizards) with:

- Conditional branching based on user answers
- State persistence across requests
- Validation at each step
- "Check your answers" review pages
- Auto-generated documentation

### When to use this gem

Use DfE::Wizard when you need:

- A form split across multiple pages
- Different paths based on user input
- Data saved between steps
- A review page before final submission

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                           WIZARD                                │
│                      (Orchestrator)                             │
│                                                                 │
│  Coordinates everything: steps, navigation, validation, state  │
└───────────────┬─────────────────────────────┬───────────────────┘
                │                             │
      ┌─────────▼──────────┐        ┌─────────▼──────────┐
      │  STEPS PROCESSOR   │        │    STATE STORE     │
      │  (Flow Definition) │        │  (Data + Logic)    │
      │                    │        │                    │
      │  Defines which     │        │  Holds all data    │
      │  steps exist and   │        │  and branching     │
      │  how they connect  │        │  predicates        │
      └────────────────────┘        └─────────┬──────────┘
                                              │
                                    ┌─────────▼──────────┐
                                    │    REPOSITORY      │
                                    │   (Persistence)    │
                                    │                    │
                                    │  Session, Redis,   │
                                    │  Database, Memory  │
                                    └────────────────────┘

      ┌────────────────────┐
      │       STEP         │
      │   (Form Object)    │
      │                    │
      │  Attributes,       │
      │  validations,      │
      │  one per screen    │
      └────────────────────┘
```

---

## Installation

This gem is distributed via GitHub tags, not RubyGems. Pin to a tag in your
Gemfile:

```ruby
gem 'dfe-wizard', require: 'dfe/wizard', github: 'DFE-Digital/dfe-wizard', tag: 'v1.0.0'
```

Then run:

```bash
bundle install
```

Bundler resolves the tag to a commit SHA and records both in your
`Gemfile.lock`, so builds stay reproducible. Released tags are never moved.

To track unreleased work instead, swap `tag:` for `branch: 'main'` — but pin to
a tag for anything you deploy.

---

## Getting Started

Let's build a registration wizard with conditional branching. Users provide their name, nationality, and email. Non-UK nationals are asked for visa details.

```
┌──────┐     ┌─────────────┐     ┌──────┐     ┌────────┐
│ name │ ──▶ │ nationality │ ──▶ │ visa │ ──▶ │ email  │ ──▶ review
└──────┘     └─────────────┘     └──────┘     └────────┘
                   │                              ▲
                   │     (UK national)            │
                   └──────────────────────────────┘
```

### Step 1: Create the Steps

```ruby
# app/wizards/steps/registration/name_step.rb
module Steps
  module Registration
    class NameStep
      include DfE::Wizard::Step

      attribute :first_name, :string
      attribute :last_name, :string

      validates :first_name, :last_name, presence: true

      def self.permitted_params
        %i[first_name last_name]
      end
    end
  end
end

# app/wizards/steps/registration/nationality_step.rb
module Steps
  module Registration
    class NationalityStep
      include DfE::Wizard::Step

      NATIONALITIES = %w[british irish european other].freeze

      attribute :nationality, :string

      validates :nationality, presence: true, inclusion: { in: NATIONALITIES }

      def self.permitted_params
        %i[nationality]
      end
    end
  end
end

# app/wizards/steps/registration/visa_step.rb
module Steps
  module Registration
    class VisaStep
      include DfE::Wizard::Step

      attribute :visa_type, :string
      attribute :visa_expiry, :date

      validates :visa_type, :visa_expiry, presence: true

      def self.permitted_params
        %i[visa_type visa_expiry]
      end
    end
  end
end

# app/wizards/steps/registration/email_step.rb
module Steps
  module Registration
    class EmailStep
      include DfE::Wizard::Step

      attribute :email, :string

      validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

      def self.permitted_params
        %i[email]
      end
    end
  end
end

# app/wizards/steps/registration/review_step.rb
module Steps
  module Registration
    class ReviewStep
      include DfE::Wizard::Step

      def self.permitted_params
        []
      end
    end
  end
end
```

### Step 2: Create the State Store

```ruby
# app/wizards/state_stores/registration_store.rb
module StateStores
  class RegistrationStore
    include DfE::Wizard::StateStore

    # Branching predicate - decides if visa step is shown
    def needs_visa?
      !%w[british irish].include?(nationality)
    end

    # Helper methods
    def full_name
      "#{first_name} #{last_name}"
    end
  end
end
```

### Step 3: Create the Wizard

```ruby
# app/wizards/registration_wizard.rb
class RegistrationWizard
  include DfE::Wizard

  def steps_processor
    DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
      # Register all steps
      graph.add_node :name, Steps::Registration::NameStep
      graph.add_node :nationality, Steps::Registration::NationalityStep
      graph.add_node :visa, Steps::Registration::VisaStep
      graph.add_node :email, Steps::Registration::EmailStep
      graph.add_node :review, Steps::Registration::ReviewStep

      # Set starting step
      graph.root :name

      # Define flow
      graph.add_edge from: :name, to: :nationality

      # Conditional: non-UK nationals go to visa, UK nationals skip to email
      graph.add_conditional_edge(
        from: :nationality,
        when: :needs_visa?,
        then: :visa,
        else: :email
      )

      graph.add_edge from: :visa, to: :email
      graph.add_edge from: :email, to: :review
    end
  end

  def route_strategy
    DfE::Wizard::RouteStrategy::NamedRoutes.new(
      wizard: self,
      namespace: 'registration'
    )
  end
end
```

### Step 4: Create the Controller

```ruby
# app/controllers/registration_controller.rb
class RegistrationController < ApplicationController
  before_action :set_wizard

  def show
    @step = @wizard.current_step
  end

  def update
    if @wizard.save_current_step
      redirect_to @wizard.next_step_path
    else
      @step = @wizard.current_step
      render :show
    end
  end

  private

  def set_wizard
    state_store = StateStores::RegistrationStore.new(
      repository: DfE::Wizard::Repository::Session.new(
        session:,
        key: :registration
      )
    )

    @wizard = RegistrationWizard.new(
      current_step: params[:step]&.to_sym || :name,
      current_step_params: params,
      state_store:
    )
  end
end
```

### Step 5: Create Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get 'registration/:step', to: 'registration#show', as: :registration
  patch 'registration/:step', to: 'registration#update'
end
```

### Step 6: Create the Views

Use a shared layout and step-specific form partials:

```erb
<!-- app/views/registration/new.html.erb -->
<%= govuk_link_to 'Back', @wizard.previous_step_path(fallback: root_path) %>

<div class="govuk-grid-row">
  <div class="govuk-grid-column-two-thirds">
    <h1 class="govuk-heading-l"><%= yield(:page_title) %></h1>

    <%= form_with model: @wizard.current_step,
          url: @wizard.current_step_path,
          scope: @wizard.current_step_name do |form| %>

      <%= form.govuk_error_summary %>
      <%= render "registration/#{@wizard.current_step_name}/form", form: %>
      <%= form.govuk_submit 'Continue' %>
    <% end %>
  </div>
</div>
```

```erb
<!-- app/views/registration/name/_form.html.erb -->
<% content_for :page_title, 'What is your name?' %>

<%= form.govuk_text_field :first_name %>
<%= form.govuk_text_field :last_name %>
```

```erb
<!-- app/views/registration/nationality/_form.html.erb -->
<% content_for :page_title, 'What is your nationality?' %>

<%= form.govuk_collection_radio_buttons :nationality,
    Steps::Registration::NationalityStep::NATIONALITIES,
    :to_s, :humanize %>
```

```erb
<!-- app/views/registration/visa/_form.html.erb -->
<% content_for :page_title, 'Visa details' %>

<%= form.govuk_text_field :visa_type %>
<%= form.govuk_date_field :visa_expiry %>
```

---

## Core Concepts

Before building a wizard, understand these five components:

```
| Component           | Purpose                                         | You Create                            |
|---------------------|-------------------------------------------------|---------------------------------------|
| **Repository**      | Where data is stored (Session, Redis, DB)       | Choose one per wizard or one per page |
| **State Store**     | Holds data + branching logic                    | Yes, one per wizard                   |
| **Step**            | One form screen with fields + validations       | Yes, one per page                     |
| **Steps Processor** | Defines flow between steps                      | Yes, inside wizard                    |
| **Wizard**          | Orchestrates everything                         | Yes, one per wizard                   |
```

### 1. Repository

The Repository is the **storage backend**. It persists wizard data between HTTP requests.

```
| Repository    | Storage            | Use Case                |
|---------------|--------------------|-------------------------|
| `InMemory`    | Ruby hash          | Testing only            |
| `Session`     | Rails session      | Simple wizards          |
| `Cache`       | Rails.cache        | Fast, temporary         |
| `Redis`       | Redis server       | Production, distributed |
| `Model`       | ActiveRecord model | Save to model each step |
| `WizardState` | Database (JSONB) | Persistent wizard state |
```

See [In Depth: Repositories](#in-depth-repositories) for detailed examples and encryption.

```ruby
# Testing
repository = DfE::Wizard::Repository::InMemory.new

# Production - Session
repository = DfE::Wizard::Repository::Session.new(
  session: session,
  key: :my_wizard
)

# Production - Database
model = WizardState.find_or_create_by(key: :my_wizard, user_id: current_user.id)
repository = DfE::Wizard::Repository::WizardState.new(model: model)
```

### 2. State Store

The State Store is the **bridge between your wizard and the repository**. It:

- Reads/writes data via the repository
- Provides attribute access (`state_store.first_name`)
- Contains **branching predicates** (methods that decide which path to take)

```ruby
module StateStores
  class Registration
    include DfE::Wizard::StateStore

    # Branching predicates - these decide the flow
    def needs_visa?
      nationality != 'british'
    end

    def has_right_to_work?
      right_to_work == 'yes'
    end

    # Helper methods
    def full_name
      "#{first_name} #{last_name}"
    end
  end
end
```

**Available methods:**

```
| Method        | Description                               |
|---------------|-------------------------------------------|
| `repository`  | Access the underlying repository          |
| `read`        | Read all data from repository             |
| `write(hash)` | Write data to repository                  |
| `clear`       | Clear all data                            |
| `[attribute]` | Dynamic accessors for all step attributes |
```

**Dynamic attribute accessors**: After wizard initialisation, all step attributes become methods on the state store. If your steps define `first_name`, `email`, and `nationality` attributes, you can call `state_store.first_name`, `state_store.email`, and `state_store.nationality`.

### 3. Step

A Step is a **form object representing one screen**. Each step has:

- Attributes (form fields)
- Validations
- Permitted parameters

```ruby
module Steps
  class PersonalDetails
    include DfE::Wizard::Step

    # Form fields
    attribute :first_name, :string
    attribute :last_name, :string
    attribute :date_of_birth, :date

    # Validations
    validates :first_name, :last_name, presence: true
    validates :date_of_birth, presence: true

    # Strong parameters
    def self.permitted_params
      %i[first_name last_name date_of_birth]
    end
  end
end
```

### 4. Steps Processor

The Steps Processor **defines the flow** - which steps exist and how they connect.

```ruby
def steps_processor
  DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
    # Register all steps
    graph.add_node :personal_details, Steps::PersonalDetails
    graph.add_node :contact, Steps::Contact
    graph.add_node :nationality, Steps::Nationality
    graph.add_node :visa, Steps::Visa
    graph.add_node :review, Steps::Review

    # Set the starting step
    graph.root :personal_details

    # Define transitions
    graph.add_edge from: :personal_details, to: :contact
    graph.add_edge from: :contact, to: :nationality

    graph.add_conditional_edge(
      from: :nationality,
      when: :needs_visa?,
      then: :visa,
      else: :review
    )

    graph.add_edge from: :visa, to: :review
  end
end
```

**Key point**: `predicate_caller: state_store` tells the graph where to find branching methods (like `needs_visa?`).

### 5. Wizard

The Wizard **orchestrates everything**. It must implement some methods:

```ruby
class RegistrationWizard
  include DfE::Wizard

  def steps_processor
    # Define your flow (see above)
  end

  def route_strategy
    # Define URL generation (see Optional Features)
  end

  def steps_operator
    # Define steps operatons on #save_current_step (see Optional Features)
  end

  def inspect
    # Define inspector for development - useful for debug (see Optional Features)
    DfE::Wizard::Tooling::Inspect.new(wizard: self) if Rails.env.development?
  end

  def logger
    # Define logger for development - useful for debug (see Optional Features)
    DfE::Wizard::Logging::Logger.new(Rails.logger) if Rails.env.development?
  end
end
```

**`inspect`** - Returns detailed debug output when you `puts wizard`:

```
#<RegistrationWizard:0x00007f8b1c0a0>
┌─ STATE LAYERS ─────────────────────────────┐
│ Current Step: :email
│ Flow Path:    [:name, :nationality, :email, :review]
│ Saved Path:   [:name, :nationality]
│ Valid Path:   [:name, :nationality]
└────────────────────────────────────────────┘
┌─ VALIDATION ───────────────────────────────┐
│ ✓ All steps valid
└────────────────────────────────────────────┘
┌─ STATE STORE ──────────────────────────────┐
│ Raw Steps:
│   name: { first_name: "Sarah", last_name: "Smith" }
│   nationality: { nationality: "british" }
└────────────────────────────────────────────┘
```

---

## Data Flow

Understanding data flow is essential. Here's what happens during a wizard:

### Write Flow (User submits a form)

```
┌──────────────────────────────────────────────────────────────────┐
│  1. HTTP Request                                                 │
│     POST /wizard/personal_details                                │
│     params: { personal_details: { first_name: "Sarah" } }        │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│  2. Controller creates Wizard                                    │
│                                                                  │
│     @wizard = RegistrationWizard.new(                            │
│       current_step: :personal_details,                           │
│       current_step_params: params,                               │
│       state_store: state_store                                   │
│     )                                                            │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│  3. Wizard extracts step params                                  │
│                                                                  │
│     Uses Step.permitted_params to filter:                        │
│     { first_name: "Sarah" }                                      │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│  4. Step validates                                               │
│                                                                  │
│     step = Steps::PersonalDetails.new(first_name: "Sarah")       │
│     step.valid?  # runs ActiveModel validations                  │
└────────────────────────┬─────────────────────────────────────────┘
                         │
              ┌──────────┴──────────┐
              │                     │
         Valid?                 Invalid?
              │                     │
              ▼                     ▼
┌─────────────────────┐   ┌─────────────────────┐
│  5a. Save to State  │   │  5b. Return Errors  │
│                     │   │                     │
│  state_store.write( │   │  step.errors        │
│    first_name:      │   │  # => { last_name:  │
│      "Sarah"        │   │  #   ["can't be     │
│  )                  │   │  #    blank"] }     │
└──────────┬──────────┘   └─────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────┐
│  6. Repository persists                                          │
│                                                                  │
│     Session/Redis/Database stores:                               │
│     { first_name: "Sarah", last_name: nil, ... }                 │
└──────────────────────────────────────────────────────────────────┘
```

### Read Flow (Loading a step)

```
┌──────────────────────────────────────────────────────────────────┐
│  1. HTTP Request                                                 │
│     GET /wizard/contact                                          │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│  2. Repository reads persisted data                              │
│                                                                  │
│     { first_name: "Sarah", email: "sarah@example.com" }          │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│  3. State Store provides data                                    │
│                                                                  │
│     state_store.first_name  # => "Sarah"                         │
│     state_store.email       # => "sarah@example.com"             │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│  4. Wizard hydrates Step                                         │
│                                                                  │
│     step = wizard.current_step                                   │
│     # Step is pre-filled with saved data                         │
│     step.email  # => "sarah@example.com"                         │
└──────────────────────────────────────────────────────────────────┘
```

### Key Points

1. **Data is stored flat** - All attributes from all steps go into one hash
2. **Repository handles persistence** - You choose where (session, Redis, DB)
3. **State Store adds behaviour** - Predicates, helpers, attribute access
4. **Steps are form objects** - They validate but don't persist directly

---

## Navigation

### Step Navigation Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `current_step_name` | Symbol | Current step ID (`:email`) |
| `current_step` | Step object | Hydrated step with data |
| `next_step` | Symbol or nil | Next step ID |
| `previous_step` | Symbol or nil | Previous step ID |
| `root_step` | Symbol | First step ID |

### Path Navigation Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `current_step_path` | String | URL for current step |
| `next_step_path` | String or nil | URL for next step |
| `previous_step_path` | String or nil | URL for previous step |

### Back Links

Use `previous_step_path` for GOV.UK back links:

```erb
<%= govuk_back_link href: @wizard.previous_step_path(fallback: root_path) %>
```

The `fallback:` option is used on the first step when there is no previous step.

### Flow Analysis Methods

The wizard tracks three different "paths":

```ruby
# Given a wizard where user filled name and email, but email is invalid:

wizard.flow_path
# => [:name, :email, :review]
# All steps the user COULD visit based on their answers

wizard.saved_path
# => [:name, :email]
# Steps that have ANY data saved

wizard.valid_path
# => [:name]
# Steps that have VALID data (stops at first invalid)

wizard.valid_path_to?(:review)
# => false (email is invalid, can't reach review)

wizard.in_flow?(:review)
# => true (review is reachable based on answers)
```

### Understanding the Three Paths

| Path | Question it answers |
|------|---------------------|
| `flow_path` | "What steps would the user visit?" |
| `saved_path` | "What steps have data?" |
| `valid_path` | "What steps are complete and valid?" |

Use cases:

```ruby
# Progress indicator
completed = wizard.valid_path.length
total = wizard.flow_path.length
progress = (completed.to_f / total * 100).round

# Guard against URL manipulation
before_action :validate_step_access

def validate_step_access
  unless wizard.valid_path_to?(params[:step].to_sym)
    redirect_to wizard.current_step_path
  end
end
```

---

## Conditional Branching

Most wizards need different paths based on user input.

### Simple Conditional (Yes/No)

```ruby
def steps_processor
  DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
    graph.add_node :nationality, Steps::Nationality
    graph.add_node :visa, Steps::Visa
    graph.add_node :review, Steps::Review

    graph.root :nationality

    # If needs_visa? is true  → go to :visa
    # If needs_visa? is false → go to :review
    graph.add_conditional_edge(
      from: :nationality,
      when: :needs_visa?,
      then: :visa,
      else: :review
    )

    graph.add_edge from: :visa, to: :review
  end
end
```

The predicate `needs_visa?` is defined in your **State Store**:

```ruby
class RegistrationStore
  include DfE::Wizard::StateStore

  def needs_visa?
    !%w[british irish].include?(nationality)
  end
end
```

### Multiple Conditions (3+ paths)

```ruby
graph.add_multiple_conditional_edges(
  from: :visa_type,
  branches: [
    { when: :student_visa?, then: :student_details },
    { when: :work_visa?, then: :employer_details },
    { when: :family_visa?, then: :family_details }
  ],
  default: :other_visa
)
```

- Evaluated **in order** - first match wins
- Always provide a `default`

### Custom Branching

For complex logic that doesn't fit the DSL:

```ruby
graph.add_custom_branching_edge(
  from: :eligibility_check,
  conditional: :determine_route,
  potential_transitions: [
    { label: 'Eligible', nodes: [:application] },
    { label: 'Not eligible', nodes: [:rejection] },
    { label: 'Needs review', nodes: [:manual_review] }
  ]
)
```

The method returns a step symbol directly:

```ruby
# In your wizard (for custom branching only)
def determine_route
  result = EligibilityService.check(state_store.read)

  case result.status
  when :eligible then :application
  when :ineligible then :rejection
  else :manual_review
  end
end
```

### Dynamic Root Step

Start at different steps based on conditions:

```ruby
graph.conditional_root(potential_root: %i[returning_user new_user]) do |state_store|
  state_store.has_account? ? :returning_user : :new_user
end
```

### Performance: Memoize Expensive Predicates

**Important**: Predicates may be called multiple times per request. Methods like `flow_path`, `previous_step`, and `valid_path` traverse the graph and evaluate predicates along the way.

If your predicate calls an external API, **memoize the result**:

```ruby
# BAD - API called multiple times per request
def eligible?
  EligibilityService.check(trn).eligible?  # Called 3+ times!
end

# GOOD - Memoize the result
def eligible?
  @eligible ||= EligibilityService.check(trn).eligible?
end

# GOOD - Memoize the whole response if you need multiple values
def eligibility_result
  @eligibility_result ||= EligibilityService.check(trn)
end

def eligible?
  eligibility_result.eligible?
end

def eligibility_reason
  eligibility_result.reason
end
```

This applies to any expensive operation: database queries, API calls, or complex calculations.

---

## Check Your Answers

The gem provides `CheckYourAnswers` to build "Check your answers" pages.

### Creating a Review Presenter

```ruby
# app/presenters/registration_review.rb
class RegistrationReview
  include DfE::Wizard::CheckYourAnswers

  def personal_details
    [
      row_for(:name, :first_name),
      row_for(:name, :last_name),
      row_for(:email, :email)
    ]
  end

  def visa_details
    [
      row_for(:nationality, :nationality),
      row_for(:visa, :visa_type, label: 'Type of visa')
    ]
  end

  # Override to format specific values
  def format_value(attribute, value)
    case attribute
    when :date_of_birth
      value&.strftime('%d %B %Y')
    else
      value
    end
  end
end
```

### Using the Presenter

In your controller:

```ruby
def show
  if @wizard.current_step_name == :review
    @review = RegistrationReview.new(@wizard)
  end
  @step = @wizard.current_step
end
```

In your view:

```erb
<h1>Check your answers</h1>

<h2>Personal details</h2>
<dl class="govuk-summary-list">
  <% @review.personal_details.each do |row| %>
    <div class="govuk-summary-list__row">
      <dt class="govuk-summary-list__key"><%= row.label %></dt>
      <dd class="govuk-summary-list__value"><%= row.formatted_value %></dd>
      <dd class="govuk-summary-list__actions">
        <%= link_to 'Change', row.change_path %>
      </dd>
    </div>
  <% end %>
</dl>
```

### Row Object

Each row provides:

| Method | Description |
|--------|-------------|
| `label` | Human-readable label (from I18n or custom) |
| `value` | Raw value |
| `formatted_value` | Formatted via `format_value` |
| `change_path` | URL with `return_to_review` param |
| `step_id` | The step ID |
| `attribute` | The attribute name |

### Return to Review Flow

When users click "Change", they go to the step with `?return_to_review=step_id`. After saving, they return to the review page.

Implement this with callbacks:

```ruby
def steps_processor
  DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
    # ... steps ...

    graph.before_next_step(:handle_return_to_review)
    graph.before_previous_step(:handle_back_to_review)
  end
end

def handle_return_to_review
  return unless current_step_params[:return_to_review].present?
  return unless valid_path_to?(:review)

  :review
end

def handle_back_to_review
  return unless current_step_params[:return_to_review].to_s == current_step_name.to_s
  return unless valid_path_to?(:review)

  :review
end
```

---

## Optional Features

### Route Strategy

Route strategies translate step symbols (`:name`, `:email`) into URLs (`/registration/name`). The wizard uses this for `next_step_path`, `previous_step_path`, and `current_step_path`.

You must implement `route_strategy` in your wizard. Three strategies are available:

**NamedRoutes** (recommended for simple wizards):

Uses Rails named routes. The `namespace` becomes the route helper prefix.

```ruby
def route_strategy
  DfE::Wizard::RouteStrategy::NamedRoutes.new(
    wizard: self,
    namespace: 'registration'
  )
end

# Uses: registration_path(:name) → /registration/name
# Uses: registration_path(:email) → /registration/email
```

Requires matching routes:

```ruby
# config/routes.rb
get 'registration/:step', to: 'registration#show', as: :registration
patch 'registration/:step', to: 'registration#update'
```

**ConfigurableRoutes** (for complex URL patterns):

```ruby
def route_strategy
  DfE::Wizard::RouteStrategy::ConfigurableRoutes.new(
    wizard: self,
    namespace: 'courses'
  ) do |config|
    config.default_path_arguments = {
      provider_code: state_store.provider_code,
      course_code: state_store.course_code
    }

    config.map_step :review, to: ->(wizard, opts, helpers) {
      helpers.course_review_path(**opts)
    }
  end
end
```

**DynamicRoutes** (for multi-instance wizards):

```ruby
def route_strategy
  DfE::Wizard::RouteStrategy::DynamicRoutes.new(
    state_store: state_store,
    path_builder: ->(step_id, state_store, helpers, opts) {
      helpers.wizard_step_path(
        state_key: state_store.state_key,
        step: step_id,
        **opts
      )
    }
  )
end
```

### Step Operators

Customise what happens when a step is saved. By default, each step runs: `Validate → Persist`.

```ruby
def steps_operator
  DfE::Wizard::StepsOperator::Builder.draw(wizard: self, callable: state_store) do |b|
    # use: replaces the entire pipeline
    b.on_step(:payment, use: [Validate, ProcessPayment, Persist])

    # add: appends to the default pipeline (Validate → Persist → YourOperator)
    b.on_step(:notification, add: [SendConfirmationEmail])

    # use: [] skips all operations (useful for review steps)
    b.on_step(:review, use: [])
  end
end
```

**`use:` - Replace the pipeline**

Completely replaces the default Validate → Persist with your operators:

```ruby
# Only validate, don't persist (dry run)
b.on_step(:preview, use: [Validate])

# Custom order: validate, process payment, then persist
b.on_step(:payment, use: [Validate, ProcessPayment, Persist])

# Skip everything (review pages that don't need saving)
b.on_step(:check_answers, use: [])
```

**`add:` - Extend the pipeline**

Adds operators after the default Validate → Persist:

```ruby
# Validate → Persist → SendConfirmationEmail
b.on_step(:final_step, add: [SendConfirmationEmail])

# Validate → Persist → NotifySlack → UpdateAnalytics
b.on_step(:submission, add: [NotifySlack, UpdateAnalytics])
```

**Custom operation class:**

```ruby
class ProcessPayment
  def initialize(repository:, step:, callable:)
    @repository = repository
    @step = step
    @callable = callable  # Your state store
  end

  def execute
    result = PaymentGateway.charge(
      amount: @step.amount,
      email: @callable.email
    )

    if result.success?
      { success: true, transaction_id: result.id }
    else
      { success: false, errors: { payment: [result.error] } }
    end
  end
end
```

Operations must return a hash with `:success` key. If `success: false`, include `:errors` to display validation messages.

### Logger (Recommended)

Enable detailed logging for debugging navigation and branching decisions:

```ruby
def logger
  DfE::Wizard::Logging::Logger.new(Rails.logger) if Rails.env.development?
end
```

Logs include step transitions, predicate evaluations, and path calculations - invaluable for debugging complex flows.

Exclude noisy categories if needed:

```ruby
DfE::Wizard::Logging::Logger.new(Rails.logger).exclude(%i[routing validation])
```

### Inspect

Debug wizard state in development:

```ruby
def inspect
  DfE::Wizard::Tooling::Inspect.new(wizard: self) if Rails.env.development?
end
```

```ruby
puts wizard.inspect
# ┌─ Wizard: RegistrationWizard
# ├─ Current Step: :email
# ├─ Flow Path: [:name, :email, :review]
# ├─ Saved Steps: [:name]
# └─ State: { first_name: "Sarah", last_name: "Smith" }
```

---

## Testing

Include the RSpec matchers:

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.include DfE::Wizard::Test::RSpecMatchers
end
```

### Navigation Matchers

```ruby
# Next step
expect(wizard).to have_next_step(:email)
expect(wizard).to have_next_step(:review).from(:email)
expect(wizard).to have_next_step(:visa).from(:nationality).when(nationality: 'canadian')

# Previous step
expect(wizard).to have_previous_step(:name)

# Root step
expect(wizard).to have_root_step(:name)

# Branching
expect(wizard).to branch_from(:nationality).to(:visa).when(nationality: 'canadian')
expect(wizard).to branch_from(:nationality).to(:review).when(nationality: 'british')
```

### Path Matchers

```ruby
expect(wizard).to have_flow_path([:name, :email, :review])
expect(wizard).to have_saved_path([:name, :email])
expect(wizard).to have_valid_path([:name])
```

### Validation Matchers

```ruby
expect(wizard).to be_valid_to(:review)
expect(:email).to be_valid_step.in(wizard)
```

### State Store Matchers

```ruby
expect(state_store).to have_step_attribute(:first_name)
expect(state_store).to have_step_attribute(:email).with_value('test@example.com')
```

---

## Auto-generated Documentation

Generate Mermaid, GraphViz, and Markdown documentation from your wizard:

```ruby
# lib/tasks/wizard_docs.rake
namespace :wizard do
  namespace :docs do
    task generate: :environment do
      output_dir = 'docs/wizards'

      [RegistrationWizard, ApplicationWizard].each do |wizard_class|
        wizard = wizard_class.new(state_store: OpenStruct.new)
        wizard.documentation.generate_all(output_dir)
        puts "Generated docs for #{wizard_class.name}"
      end
    end
  end
end
```

Run with:

```bash
rake wizard:docs:generate
```

---

## In Depth: Repositories

Repositories handle data persistence. All repositories implement the same interface:

```ruby
repository.read   # => Hash
repository.write(hash)
repository.clear
```

### InMemory Repository

Stores data in a Ruby hash. **Testing only** - data lost on each request.

```ruby
repository = DfE::Wizard::Repository::InMemory.new

repository.write(first_name: 'Sarah')
repository.read  # => { first_name: 'Sarah' }

# Data is lost when the object is garbage collected
```

### Session Repository

Stores data in Rails session. Good for simple wizards without sensitive data.

```ruby
repository = DfE::Wizard::Repository::Session.new(
  session: session,
  key: :registration_wizard
)

# Data stored at session[:registration_wizard]
repository.write(first_name: 'Sarah')
session[:registration_wizard]  # => { first_name: 'Sarah' }
```

### Cache Repository

Stores data in Rails.cache. Good for distributed systems with expiring data.

```ruby
repository = DfE::Wizard::Repository::Cache.new(
  cache: Rails.cache,
  key: "wizard:#{current_user.id}:registration",
  expires_in: 1.hour
)

# Data stored in cache with automatic expiration
repository.write(first_name: 'Sarah')
```

### Redis Repository

Stores data directly in Redis. Good for high-throughput systems.

```ruby
repository = DfE::Wizard::Repository::Redis.new(
  redis: Redis.current,
  key: "wizard:#{session.id}:registration",
  expires_in: 24.hours
)

# Data stored as JSON in Redis
repository.write(first_name: 'Sarah')
Redis.current.get("wizard:#{session.id}:registration")
# => '{"first_name":"Sarah"}'
```

### Model Repository

Persists data directly to an ActiveRecord model. Each `write` calls `update!`.

```ruby
# Your model
class Application < ApplicationRecord
  # Must have columns matching step attributes
  # e.g., first_name, last_name, email, etc.
end

application = Application.find_or_create_by(user: current_user)
repository = DfE::Wizard::Repository::Model.new(model: application)

# Each write updates the model
repository.write(first_name: 'Sarah')
application.reload.first_name  # => 'Sarah'
```

**Use when**: You want each step to immediately persist to your domain model.

### WizardState Repository

Stores all wizard data in a JSONB column. Good for complex wizards with many fields.

**Migration:**

```ruby
class CreateWizardStates < ActiveRecord::Migration[7.1]
  def change
    create_table :wizard_states do |t|
      t.string :key, null: false
      t.string :user_id
      t.jsonb :state, default: {}
      t.timestamps
    end

    add_index :wizard_states, [:key, :user_id], unique: true
  end
end
```

**Model:**

```ruby
class WizardState < ApplicationRecord
  validates :key, presence: true
end
```

**Usage:**

```ruby
model = WizardState.find_or_create_by(
  key: 'registration',
  user_id: current_user&.id
)
repository = DfE::Wizard::Repository::WizardState.new(model: model)

# All data stored in the JSONB 'state' column
repository.write(first_name: 'Sarah', email: 'sarah@example.com')
model.reload.state  # => { "first_name" => "Sarah", "email" => "sarah@example.com" }
```

### Encryption

All repositories that inherit from `Base` support encryption for sensitive data. Pass `encrypted: true` and an `encryptor:` object that responds to `encrypt_and_sign` and `decrypt_and_verify` (like `ActiveSupport::MessageEncryptor`).

```ruby
# Create an encryptor
key = Rails.application.credentials.wizard_encryption_key
encryptor = ActiveSupport::MessageEncryptor.new(key)

# Use with any repository
repository = DfE::Wizard::Repository::Session.new(
  session: session,
  key: :secure_wizard,
  encrypted: true,
  encryptor: encryptor
)

# Data is encrypted before storage
repository.write(national_insurance: 'AB123456C')
session[:secure_wizard]  # => { national_insurance: "encrypted_string..." }
```

### Multiple Wizard Instances (state_key)

When users can have multiple instances of the same wizard running simultaneously (e.g., multiple browser tabs, or editing multiple applications), use `state_key` to isolate each instance's data.

**The problem**: Without `state_key`, all tabs share the same data. User opens two tabs to create two different applications - data from one overwrites the other.

**The solution**: Generate a unique `state_key` for each wizard instance and pass it through the URL.

```ruby
# Controller
class ApplicationsController < ApplicationController
  def new
    # Generate a new state_key for a fresh wizard instance
    redirect_to application_step_path(state_key: SecureRandom.uuid, step: :name)
  end

  def show
    @wizard = build_wizard
  end

  def update
    @wizard = build_wizard
    if @wizard.save_current_step
      redirect_to application_step_path(state_key: params[:state_key], step: @wizard.next_step)
    else
      render :show
    end
  end

  private

  def build_wizard
    state_store = StateStores::ApplicationStore.new(
      repository: DfE::Wizard::Repository::Session.new(
        session: session,
        key: :applications,
        state_key: params[:state_key]  # Each instance gets its own namespace
      )
    )

    ApplicationWizard.new(
      current_step: params[:step].to_sym,
      current_step_params: params,
      state_store: state_store
    )
  end
end
```

```ruby
# Routes
get 'applications/:state_key/:step', to: 'applications#show', as: :application_step
patch 'applications/:state_key/:step', to: 'applications#update'
```

**How it works in Session:**

```ruby
# Without state_key - single flat hash
session[:wizard_store] = { first_name: 'Sarah', ... }

# With state_key - nested by instance
session[:applications] = {
  'abc-123' => { first_name: 'Sarah', ... },   # Tab 1
  'def-456' => { first_name: 'James', ... }    # Tab 2
}
```

**With Redis:**

```ruby
repository = DfE::Wizard::Repository::Redis.new(
  redis: Redis.current,
  key: "wizard:user:#{current_user.id}",
  state_key: params[:state_key],
  expiration: 24.hours
)
```

### Choosing a Repository

| Scenario                             | Recommended Repository |
|--------------------------------------|------------------------|
| Testing                              | InMemory               |
| Simple wizard, no sensitive data     | Session                |
| Distributed system, temporary data   | Cache or Redis         |
| Persist to existing model            | Model                  |
| Complex wizard, many fields          | WizardState            |
| Sensitive data                       | Any with encryption    |

---

## In Depth: Steps

Steps are ActiveModel objects representing individual screens in your wizard.

### Step Attributes

Use ActiveModel attributes with types:

```ruby
class PersonalDetails
  include DfE::Wizard::Step

  attribute :first_name, :string
  attribute :last_name, :string
  attribute :date_of_birth, :date
  attribute :age, :integer
  attribute :newsletter, :boolean, default: false
  attribute :preferences, :json  # For complex data
end
```

### Attribute Uniqueness

**Important**: Step attribute names must be unique across the entire wizard.

```ruby
# BAD - 'email' is defined in two steps
class ContactStep
  attribute :email, :string
end

class NotificationStep
  attribute :email, :string  # Conflict! Will overwrite ContactStep's email
end

# GOOD - unique attribute names
class ContactStep
  attribute :contact_email, :string
end

class NotificationStep
  attribute :notification_email, :string
end
```

This is because all attributes are stored in a flat hash in the repository.

### Permitted Parameters

Always define `permitted_params` to control which params are accepted:

```ruby
class AddressStep
  include DfE::Wizard::Step

  attribute :address_line_1, :string
  attribute :address_line_2, :string
  attribute :postcode, :string
  attribute :country, :string

  def self.permitted_params
    %i[address_line_1 address_line_2 postcode country]
  end
end
```

### Nested Attributes

For nested params (like GOV.UK date inputs):

```ruby
class DateOfBirthStep
  include DfE::Wizard::Step

  attribute :date_of_birth, :date

  def self.permitted_params
    [date_of_birth: %i[day month year]]
  end
end
```

### Custom Validations

Steps use ActiveModel validations:

```ruby
class EligibilityStep
  include DfE::Wizard::Step

  attribute :age, :integer
  attribute :country, :string

  validates :age, numericality: { greater_than_or_equal_to: 18 }
  validates :country, inclusion: { in: %w[england wales scotland] }

  validate :must_be_eligible

  private

  def must_be_eligible
    if age.present? && age < 21 && country == 'scotland'
      errors.add(:base, 'Must be 21 or older in Scotland')
    end
  end
end
```

### Accessing Other Step Data

Steps can access data from other steps via the state store:

```ruby
class SummaryStep
  include DfE::Wizard::Step

  def full_name
    "#{state_store.first_name} #{state_store.last_name}"
  end

  def formatted_address
    [
      state_store.address_line_1,
      state_store.address_line_2,
      state_store.postcode
    ].compact.join(', ')
  end
end
```

---

## In Depth: Conditional Edges

The Graph processor supports several edge types for branching logic.

### Simple Edge

Unconditional transition from one step to another:

```ruby
graph.add_edge from: :name, to: :email
```

```
  ┌──────┐      ┌───────┐
  │ name │ ───▶ │ email │
  └──────┘      └───────┘
```

### Conditional Edge

Binary branching based on a predicate:

```ruby
graph.add_conditional_edge(
  from: :nationality,
  when: :needs_visa?,        # Method on state_store
  then: :visa_details,       # If true
  else: :employment,         # If false
  label: 'Visa required?'    # Optional: for documentation
)
```

```
                    ┌───────────────┐
              yes   │ visa_details  │
           ┌──────▶ └───────────────┘
  ┌─────────────┐
  │ nationality │ ── needs_visa? ──┐
  └─────────────┘                  │
                    ┌───────────────┐
              no    │  employment   │
           └──────▶ └───────────────┘
```

**Predicates can be:**

```ruby
# Symbol - method on state_store
when: :needs_visa?

# Proc - inline logic
when: -> { state_store.nationality != 'british' }
```

### Multiple Conditional Edge

Three or more branches, evaluated in order:

```ruby
graph.add_multiple_conditional_edges(
  from: :employment_status,
  branches: [
    { when: :employed?, then: :employer_details, label: 'Employed' },
    { when: :self_employed?, then: :business_details, label: 'Self-employed' },
    { when: :student?, then: :education_details, label: 'Student' }
  ],
  default: :other_status  # Required: fallback
)
```

```
                        ┌──────────────────┐
              employed  │ employer_details │
           ┌──────────▶ └──────────────────┘
           │
  ┌────────────────┐    ┌──────────────────┐
  │employment_status│ ─▶│ business_details │ (self-employed)
  └────────────────┘    └──────────────────┘
           │
           │            ┌──────────────────┐
           └──────────▶ │ education_details│ (student)
           │            └──────────────────┘
           │
           │            ┌──────────────────┐
           └──(default)▶│   other_status   │
                        └──────────────────┘
```

**Evaluation order matters** - first matching predicate wins:

```ruby
branches: [
  { when: :high_priority?, then: :fast_track },   # Checked first
  { when: :medium_priority?, then: :standard },   # Checked second
  { when: :any_priority?, then: :slow_track }     # Checked last
]
```

### Custom Branching Edge

For complex logic that returns the next step directly:

```ruby
graph.add_custom_branching_edge(
  from: :assessment,
  conditional: :calculate_route,  # Method that returns step symbol
  potential_transitions: [        # For documentation only
    { label: 'Score > 80', nodes: [:fast_track] },
    { label: 'Score 50-80', nodes: [:standard] },
    { label: 'Score < 50', nodes: [:remedial] }
  ]
)
```

Define the method in your **wizard** (not state store):

```ruby
class ApplicationWizard
  include DfE::Wizard

  def calculate_route
    score = AssessmentService.score(state_store.read)

    case score
    when 81..100 then :fast_track
    when 50..80  then :standard
    else :remedial
    end
  end
end
```

### Dynamic Root

Start the wizard at different steps based on conditions:

```ruby
# Using a block
graph.conditional_root(potential_root: %i[new_user returning_user]) do |state_store|
  state_store.existing_user? ? :returning_user : :new_user
end

# Using a method
graph.conditional_root(:determine_start, potential_root: %i[new_user returning_user])
```

### Skip When

Skip steps based on conditions. The step remains in the graph but is jumped over during navigation.

```ruby
graph.add_node :school_selection, SchoolSelection, skip_when: :only_one_school?

# In state store
def only_one_school?
  available_schools.count == 1
end
```

**Why use skip_when instead of conditional edges?**

Without explicit skipping, a conditional edge on step A must decide not only whether to go to B, but also where to go after B if B is not needed, leading to logic like: "if X then go to B else go to C, but if Y also skip straight to D", which quickly gets messy as you add "next next next" possibilities.

With skipping, conditional edges remain local: A still points to B, B still points to C, and only B knows when it should be removed from the path. This keeps branching logic simpler, more testable, and easier to extend over time.

**Be careful with this feature, use it wisely!**

### Before Callbacks

Execute logic before navigation:

```ruby
graph.before_next_step(:handle_special_case)
graph.before_previous_step(:handle_back_navigation)

# In wizard - return step symbol to override, nil to continue
def handle_special_case
  return :review if returning_to_review?
  nil  # Continue normal navigation
end
```

---

## In Depth: Route Strategies

Route strategies translate step IDs to URLs.

### NamedRoutes Strategy

Uses Rails named routes. Simplest option.

```ruby
def route_strategy
  DfE::Wizard::RouteStrategy::NamedRoutes.new(
    wizard: self,
    namespace: 'registration'
  )
end
```

**Required routes:**

```ruby
# config/routes.rb
get 'registration/:step', to: 'registration#show', as: :registration
patch 'registration/:step', to: 'registration#update'
```

**URL generation:**

```ruby
wizard.current_step_path  # => '/registration/name'
wizard.next_step_path     # => '/registration/email'
wizard.next_step_path(return_to_review: :name)  # => '/registration/email?return_to_review=name'
```

### ConfigurableRoutes Strategy

For complex URL patterns or nested resources:

```ruby
def route_strategy
  DfE::Wizard::RouteStrategy::ConfigurableRoutes.new(
    wizard: self,
    namespace: 'applications'
  ) do |config|
    # Default arguments for all paths
    config.default_path_arguments = {
      application_id: state_store.application_id
    }

    # Custom path for specific steps
    config.map_step :review, to: ->(wizard, opts, helpers) {
      helpers.application_review_path(
        application_id: wizard.state_store.application_id,
        **opts
      )
    }

    config.map_step :submit, to: ->(wizard, opts, helpers) {
      helpers.submit_application_path(
        application_id: wizard.state_store.application_id
      )
    }
  end
end
```

### DynamicRoutes Strategy

For multi-instance wizards where URLs need to include a unique identifier (like `state_key`). This is the recommended strategy when using `state_key` for multiple wizard instances.

**Why use DynamicRoutes?**

- URLs include the instance identifier: `/applications/abc-123/name`
- Works seamlessly with `state_key` repository pattern
- The `path_builder` lambda gives you full control over URL generation

**The path_builder receives:**

| Argument | Description |
|----------|-------------|
| `step_id` | The step symbol (`:name`, `:email`) |
| `state_store` | Your state store instance (access `state_key` via repository) |
| `helpers` | Rails URL helpers |
| `opts` | Additional options passed to path methods |

**Complete example with state_key:**

```ruby
# Wizard
class ApplicationWizard
  include DfE::Wizard

  def route_strategy
    DfE::Wizard::RouteStrategy::DynamicRoutes.new(
      state_store: state_store,
      path_builder: ->(step_id, state_store, helpers, opts) {
        helpers.application_step_path(
          state_key: state_store.repository.state_key,
          step: step_id,
          **opts
        )
      }
    )
  end
end
```

```ruby
# Routes
get 'applications/:state_key/:step', to: 'applications#show', as: :application_step
patch 'applications/:state_key/:step', to: 'applications#update'
```

```ruby
# Controller
def build_wizard
  repository = DfE::Wizard::Repository::Session.new(
    session: session,
    key: :applications,
    state_key: params[:state_key]
  )

  state_store = StateStores::ApplicationStore.new(repository: repository)

  ApplicationWizard.new(
    current_step: params[:step].to_sym,
    current_step_params: params,
    state_store: state_store
  )
end
```

Now `@wizard.next_step_path` automatically includes the `state_key`:

```ruby
@wizard.next_step_path
# => "/applications/abc-123-def/email"

@wizard.next_step_path(return_to_review: true)
# => "/applications/abc-123-def/email?return_to_review=true"
```

---

## Advanced: Custom Implementations

### Custom Repository

Create repositories for other storage backends:

```ruby
class DfE::Wizard::Repository::DynamoDB
  def initialize(table_name:, key:)
    @client = Aws::DynamoDB::Client.new
    @table_name = table_name
    @key = key
  end

  def read
    response = @client.get_item(
      table_name: @table_name,
      key: { 'id' => @key }
    )
    response.item&.dig('data') || {}
  end

  def write(data)
    current = read
    merged = current.merge(data.stringify_keys)

    @client.put_item(
      table_name: @table_name,
      item: { 'id' => @key, 'data' => merged }
    )
  end

  def clear
    @client.delete_item(
      table_name: @table_name,
      key: { 'id' => @key }
    )
  end
end
```

### Custom Step Operator

Create operators for special processing:

```ruby
class SendNotification
  def initialize(repository:, step:, callable:)
    @repository = repository
    @step = step
    @callable = callable  # Your state store
  end

  def execute
    NotificationMailer.step_completed(
      email: @callable.email,
      step: @step.class.name
    ).deliver_later

    { success: true }
  end
end

# Usage
def steps_operator
  DfE::Wizard::StepsOperator::Builder.draw(wizard: self, callable: state_store) do |b|
    b.on_step(:final_step, add: [SendNotification])
  end
end
```

### Custom Repository Transform

Override `transform_for_read` and `transform_for_write` on your repository to control how data flows between the wizard and your data store. This is particularly useful for:

- Mapping step attributes to different column names
- Working around the step attribute uniqueness constraint
- Adapting to existing database schemas

**Example: Mapping prefixed attributes to a flat model**

If you have two steps that both conceptually have an "email" field, you must use unique attribute names (`contact_email`, `billing_email`). But your model might just have `email` and `billing_email`:

```ruby
class MyRepository < DfE::Wizard::Repository::Model
  # Transform data when reading FROM data store (data store → wizard)
  def transform_for_read(data)
    data.merge(
      'contact_email' => data['email']  # Map model's 'email' to step's 'contact_email'
    )
  end

  # Transform data when writing TO data store (wizard → data store)
  def transform_for_write(data)
    transformed = data.dup
    if transformed.key?('contact_email')
      transformed['email'] = transformed.delete('contact_email')  # Map back
    end
    transformed
  end
end
```

This lets your steps use descriptive, unique attribute names while your database uses its existing schema.

---

## Examples

Working examples in this repository:

- [Personal Information Wizard](spec/rails-dummy/app/wizards/personal_information_wizard.rb) - Conditional nationality flow
- [Register ECT Wizard](spec/rails-dummy/app/wizards/register_ect_wizard.rb) - Complex branching with multiple conditions
- [A-Levels Wizard](spec/rails-dummy/app/wizards/a_levels_requirements_wizard.rb) - Dynamic root, looping

Generated documentation: [spec/rails-dummy/docs/wizards](spec/rails-dummy/docs/wizards)

---

## API Reference

### Wizard Methods

**Navigation:**
- `current_step_name` → Symbol
- `current_step` → Step object
- `next_step` → Symbol or nil
- `previous_step` → Symbol or nil
- `root_step` → Symbol
- `current_step_path(options = {})` → String
- `next_step_path(options = {})` → String or nil
- `previous_step_path(fallback: nil)` → String or nil

**Flow Analysis:**
- `flow_path(target = nil)` → Array of Symbols
- `saved_path(target = nil)` → Array of Symbols
- `valid_path(target = nil)` → Array of Symbols
- `in_flow?(step_id)` → Boolean
- `saved?(step_id)` → Boolean
- `valid_path_to?(step_id)` → Boolean

**Step Hydration:**
- `step(step_id)` → Step object
- `flow_steps` → Array of Step objects
- `saved_steps` → Array of Step objects
- `valid_steps` → Array of Step objects

**State:**
- `save_current_step` → Boolean
- `current_step_valid?` → Boolean
- `state_store` → StateStore instance

### Step Methods

- `valid?` → Boolean
- `errors` → ActiveModel::Errors
- `serializable_data` → Hash
- `self.permitted_params` → Array of Symbols

### State Store Methods

- `read` → Hash
- `write(hash)` → void
- `clear` → void
- `[](key)` → value

### Repository Methods

- `read` → Hash
- `write(hash)` → void
- `clear` → void

---

## Troubleshooting

### "Predicate method :xxx not found"

Your branching predicate isn't defined on the state store:

```ruby
# In state store
def needs_visa?
  nationality != 'british'
end
```

### Step attributes not accessible in state store

The wizard must be initialised before accessing attributes:

```ruby
# Wrong - wizard not created yet
state_store.first_name  # => NoMethodError

# Right - after wizard initialisation
wizard = MyWizard.new(state_store: state_store, ...)
state_store.first_name  # => "Sarah"
```

### Data not persisting

Check your repository:

```ruby
wizard.state_store.repository.class
# => DfE::Wizard::Repository::InMemory  # This won't persist!

# Use Session or WizardState for persistence
```

### Validation failing unexpectedly

Check permitted_params includes all fields:

```ruby
def self.permitted_params
  %i[first_name last_name]  # Must include all validated fields
end
```

---

## Support

- **Issues**: [GitHub Issues](https://github.com/DFE-Digital/dfe-wizard/issues)

## Contributing

```bash
git clone git@github.com:DFE-Digital/dfe-wizard.git
cd dfe-wizard
bundle install
(cd spec/rails-dummy && bundle install && bundle exec rails db:create db:schema:load RAILS_ENV=test)
bundle exec rake            # rspec + rubocop
```

The suite runs against a Rails dummy app in `spec/rails-dummy` and needs
PostgreSQL. Set `RAILS_VERSION` to develop against a different Rails — see
[RELEASING.md](RELEASING.md), which also covers how releases are cut.

## License

MIT License - See LICENSE file
