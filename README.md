# Dfe::Wizard

DfE::Wizard is a Ruby gem for creating and managing multi-step wizards in your Rails application following a certain design.

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/dfe/wizard`. To experiment with that code, run `bin/console` for an interactive prompt.

## Installation

Add this line to your application's Gemfile:

```ruby
    gem 'dfe-wizard', require: 'dfe/wizard', github: 'DFE-Digital/dfe-wizard'
```

And then execute:

```
bundle install
```

## Usage

Creating wizards:

```ruby
class MyWizard < DfE::Wizard::Base
  steps do
    # The sequence doesn't matter. This just is a mapping (an analogy much like rails
    # routes mapping).
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

You can instantiate the wizard (normally in the controller):

```ruby
  @wizard = MyWizard.new(
    current_step: :first_step,
    step_params: ActionController::Parameters.new({ first_step: { answer: 'yes' } }),
  )
```

## Defining the steps

Each step is represented by a class that inherits from DfE::Wizard::Step.
DfE::Wizard::Step includes ActiveModel::Model, so you can use ActiveModel validations in your step classes:


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

With this defined on another action you can implement the following:


With that you gain some methods

```ruby
  def create
    @wizard = CourseSelectionWizard.new(
      current_step: :first_step,
      step_params: { answer: 'yes' },
    )

    if @wizard.valid_step? # you can call #valid_step? or #save (see save below)
      redirect_to @wizard.next_step_path
    else
      render :new
    end
  end
```

Something to note:

1. `wizard.current_step` is an instance of MyWizard::FirstStep on the example above
2. `wizard.valid_step?` is the same as `wizard.current_step.valid?`

```ruby
  # by convention:
  #   1. The code will call FirstStep#next_step idenfying the step based on your implementation
  #   2. The code will find the named routes with the step name on it (ThirdStep for "yes", SecondStep for "no")
  wizard.next_step_path

  wizard.previous_step_path # same but you need to implement previous_step
```

## Saving mechanism

```ruby
class MyWizard < DfE::Wizard::Base
  steps do
    # The sequence doesn't matter. This just is a mapping (an analogy much like rails
    # routes mapping).
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
```

Then you have to implement the #save method in the store class that you defined
above:

```ruby
  class MyStore < DfE::Wizard::Store
    def save
      # here you have wizard
      SomeModel.create!(answer: wizard.current_step.answer)
      # or feel free to not do anything for a particular step
    end
  end
```

If you call @wizard.save, the whole @wizard object will be called upon the
instance of the store (e.g MyStore above):

```ruby
@wizard.save # will trigger the save on MyStore#save
```

## Extra attributes

The wizard is just as normal class so you can add any extra attributes like
`current_user` etc:

```ruby
class MyWizard < DfE::Wizard::Base
  attr_accessor :current_user, :any_other_attribute
end
```

Just don't forget to pass in the initialize:

```ruby
  @wizard = MyWizard.new(
    current_step: :first_step,
    step_params: { answer: 'yes' },
    current_user: some_user,
    any_other_attribute: 'foo',
  )
```

## Logging

When you're developing multi step forms you need to know what permitted params
is passed between each step you can log by implementing the logger method in
the wizard


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

**I do recommend to add the "if development" to not log any sensitive data in production.**

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/DFE-Digital/dfe-wizard.
