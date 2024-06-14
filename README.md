# DfE::Wizard

DfE::Wizard is a Ruby gem designed for creating and managing multi-step wizards in your Rails application, following a specific design pattern.

## Table of Contents
- [Installation](#installation)
- [Usage](#usage)
- [Defining the Steps](#defining-the-steps)
- [Saving Mechanism](#saving-mechanism)
- [Extra Attributes](#extra-attributes)
- [Namespace routes](#namespace-routes)
- [Logging](#logging)
- [Development](#development)
- [Contributing](#contributing)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dfe-wizard', require: 'dfe/wizard', github: 'DFE-Digital/dfe-wizard'
```

And then execute:

```bash
bundle install
```

## Usage

### Creating Wizards

To create a wizard, define a class that inherits from `DfE::Wizard::Base`. The steps of the wizard are defined within a block.

```ruby
class MyWizard < DfE::Wizard::Base
  steps do
    [
      {
        first_step: FirstStep,
        second_step: SecondStep,
        third_step: ThirdStep,
        # Add more steps as needed
      }
    ]
  end
end
```

### Instantiating the Wizard

Typically, you instantiate the wizard in your controller:

```ruby
@wizard = MyWizard.new(
  current_step: :first_step,
  step_params: ActionController::Parameters.new({ first_step: { answer: 'yes' } }),
)
```

## Defining the Steps

Each step is represented by a class that inherits from `DfE::Wizard::Step`. `DfE::Wizard::Step` includes `ActiveModel::Model`, so you can use ActiveModel validations in your step classes:

```ruby
class FirstStep < DfE::Wizard::Step
  attr_accessor :answer
  validates :answer, presence: true

  def self.permitted_params
    [:answer]
  end

  def previous_step
    :first_step
  end

  def next_step
    if answer == 'yes'
      :third_step
    elsif answer == 'no'
      :second_step
    end
  end
end

class SecondStep < DfE::Wizard::Step
  # ...
end

class ThirdStep < DfE::Wizard::Step
  # ...
end
```

### Handling Wizard Actions in Controller

In your controller, you can handle the wizard actions as follows:

```ruby
def create
  @wizard = MyWizard.new(
    current_step: :first_step,
    step_params: ActionController::Parameters.new({ first_step: { answer: 'yes' } }),
  )

  if @wizard.valid_step?
    redirect_to @wizard.next_step_path
  else
    render :new
  end
end
```

### Notes

1. `wizard.current_step` is an instance of `MyWizard::FirstStep` in the example above.
2. `wizard.valid_step?` is the same as `wizard.current_step.valid?`.

```ruby
# By convention:
# 1. The code will call FirstStep#next_step to identify the next step based on your implementation.
# 2. The code will find the named routes with the step name (ThirdStep for "yes", SecondStep for "no").
# 3. In the example this will return the same as if you add "third_step_path" or
# "second_step_path" (depending on the answer is yes or no)
wizard.next_step_path

wizard.previous_step_path # similar, but you need to implement previous_step
```

## Saving Mechanism

To save the wizard's state, you need to define a store class and implement the `#save` method.

```ruby
class MyWizard < DfE::Wizard::Base
  steps do
    [
      {
        first_step: FirstStep,
        second_step: SecondStep,
        third_step: ThirdStep,
        # Add more steps as needed
      }
    ]
  end

  store MyStore
end

class MyStore < DfE::Wizard::Store
  def save
    SomeModel.create!(answer: wizard.current_step.answer)
    # Optionally, do nothing for certain steps
  end
end
```

When you call `@wizard.save`, the `save` method on `MyStore` will be triggered:

```ruby
@wizard.save # will trigger MyStore#save
```

## Extra Attributes

You can add extra attributes to your wizard class, such as `current_user`:

```ruby
class MyWizard < DfE::Wizard::Base
  attr_accessor :current_user, :any_other_attribute
end

@wizard = MyWizard.new(
  current_step: :first_step,
  step_params: ActionController::Parameters.new({ first_step: { answer: 'yes' } }),
  current_user: some_user,
  any_other_attribute: 'foo',
)
```

## Namespace routes

If the wizard steps routes is under a namespace / scope routes you can define the
defaults inside of a wizard.

In the example above all wizard routes will be under:

    /publish/organisations/:provider_code/:recruitment_cycle_year/courses/:course_code/ALL-WIZARD-STEPS-ROUTES-HERE


This mean the wizard will have to pass provider_code, recruitment_cycle_year, course_code
in every step routing.

```ruby
  def default_path_arguments
    { provider_code:, recruitment_cycle_year:, course_code: }
  end
```

Now to tell the library what is namespace / scope prefix:

```
publish_provider_recruitment_cycle_course_name_of_the_step_path
```

publish_provider_recruitment_cycle_course - defined below
named_of_the_step - based on step name identifier

```ruby
  def default_path_prefix
    'publish_provider_recruitment_cycle_course'
  end
```

The final result example in mywizard:

```ruby
class MyWizard < DfE::Wizard::Base
  steps do
    [
      {
        first_step: FirstStep,
        second_step: SecondStep,
        third_step: ThirdStep,
        # Add more steps as needed
      }
    ]
  end

  def default_path_prefix
    'publish_provider_recruitment_cycle_course'
  end

  def default_path_arguments
    { provider_code:, recruitment_cycle_year:, course_code: }
  end
end

this will make `wizard.next_step_path` to call the following named routes
passing the default_path_arguments as parameter

```ruby
publish_provider_recruitment_cycle_course_first_step_path
# => /publish/organisations/:provider_code/:recruitment_cycle_year/courses/:course_code/first-step

publish_provider_recruitment_cycle_course_second_step_path
/publish/organisations/:provider_code/:recruitment_cycle_year/courses/:course_code/second-step

publish_provider_recruitment_cycle_course_third_step_path
# => /publish/organisations/:provider_code/:recruitment_cycle_year/courses/:course_code/third-step
```

## Logging

To log the permitted parameters passed between steps, implement the logger method in the wizard:

```ruby
class MyWizard < DfE::Wizard::Base
  def logger
    DfE::Wizard::Logger.new(Rails.logger, if: -> { Rails.env.development? })
  end
end
```

This will log the following:

```
DfE::Wizard Instantiate steps with: {"answer"=>"yes"}
DfE::Wizard Finding next step for FirstStep
DfE::Wizard Next step name defined: third_step
DfE::Wizard Next step class found: ThirdStep
```

*Note: It is recommended to use conditional logging to avoid logging sensitive data in production.*

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/DFE-Digital/dfe-wizard](https://github.com/DFE-Digital/dfe-wizard).
