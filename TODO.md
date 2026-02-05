## What needs to be done

### State store inspection

Would be good to inspect the state store all step attributes and return what is on repository in
a very explanable manner (step attribute and repository value):

```ruby
state_store.inspect
```

### README

The readme is a mess.

We need to explain many concepts first:

* Repository
* State Store
* Step
* Wizard
* Route Strategy
* Steps Processors
* Steps operator
* Inspect
* Logger

MOST IMPORTANT: Explain data flow:

* The data flow - devs are confusing
* Explain in ASCII diagram
* Make simple examples

Explain Navigation flow:

* DSL Definitions on Wizard#steps_processor
* Method definitions in wizard (although state store is recommended)
* Explain flow_path, saved_path, valid_path
* Explain current_step, next_step, previous_step
* Explain current_step_path, next_step_path, previous_step_path
* Previous path uses flow_path therefore makes sure there are no circular flow

Explain steps instantiation (if needed):
* flow_steps, saved_steps, valid_steps

Explain implementing check your answers page:
* Document the CheckAnswersPresenter module
* Show how to create custom presenter classes with row grouping
* Explain format_value override for custom formatting

We need to enforce the decisions developers needs to make when using the gem and implementing a
wizard.

Things you need to defined (where to store data? Create one repo for all steps - maybe one - maybe many).
