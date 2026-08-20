## [1.0.0] - 2026-08-20

First stable release. The API is now frozen — subsequent breaking changes will
require a major version.

### Breaking changes

Both affect code written against `1.0.0.beta`. Nothing changes for users of
`0.1.x`, who should read the `1.0.0.beta` notes below as well.

- **`predicate_caller:` is now a required keyword on `StepsProcessor::Graph.draw`.**
  Branching predicates are resolved against an explicit object rather than
  being guessed at, which makes it possible to keep predicates on the state
  store and out of the wizard. Every graph wizard needs updating:

      # before
      DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|

      # after
      DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|

- **`StateStore` no longer uses `method_missing`.** Assigning
  `attribute_names=` now generates real accessor methods for those attributes,
  so attribute access is visible to `respond_to?`, appears in backtraces, and
  does not silently swallow typos. Reading an attribute that is not declared by
  any step raises `NoMethodError` where it previously fell through to
  `method_missing`. Existing methods on the state store are never overwritten,
  and `step_attributes_methods?` still turns generation off.

### Added

- **`CheckAnswersPresenter`** for building "check your answers" pages, with
  `reviewable_steps`, row grouping, and a `format_value` hook for custom
  formatting.
- `Repository::Model`, `StepsProcessor::Base` and `StepsProcessor::Linear` are
  now autoloaded — they previously had to be required by hand.
- Declared supported versions: Ruby 3.2–3.4 and Rails 7.1–8.1, each combination
  exercised by CI. The `activemodel`/`activesupport` dependencies carry a
  version range for the first time, so incompatibilities surface during
  `bundle install` rather than at runtime.
- MIT licence, now also declared in the gemspec.

### Fixed

- Graphviz graph names are sanitised, so wizard class names containing
  characters that are invalid in DOT no longer produce broken output.
- Predicate resolution is applied consistently across `Graph.draw` and the
  graph DSL; some paths previously bypassed it.

### Documentation

- Full README rewrite covering data flow, navigation, repositories, route
  strategies and testing.
- `RELEASING.md` documents the release procedure. Note that this gem is
  distributed via GitHub tags, not RubyGems.

## [1.0.0.beta] - 2025-12-22

- **New step engine**: Replaces the original linear `steps do [...] end` DSL with pluggable steps processors (linear and graph) that support branching, skipped steps, and dynamic root.
- **Richer state model**: Introduces a `StateStore` abstraction and repository layer (in‑memory, session, cache, Redis, model/JSON, wizard state) with optional per‑field encryption, plus `data/raw_data`, `flow_path/saved_path/valid_path`, metadata, and completion flags.
- **First‑class step objects**: Steps are now standalone ActiveModel form objects with typed attributes, `serializable_data`, strong params via `permitted_params`, and value semantics for easier testing.
- **Operations pipeline**: Adds configurable per‑step operations (e.g. validate, persist, custom business actions) via a `steps_operator` builder, instead of hard‑wired “save” behaviour.
- **Navigation and routing**: Standardises navigation (`next_step`, `previous_step`, `path_traversal`, `in_flow?`) and introduces pluggable routing strategies for step URLs.
- **Testing helpers**: Provides an RSpec matcher suite for flow, branching, validity, paths and operations, making wizard behaviour testable at a higher level.
- **Auto‑generated docs**: Adds documentation generators (Markdown, Mermaid, GraphViz) driven from processor metadata, with a rake task pattern for exporting all wizard flows.
- **Logging & introspection**: Adds optional structured logging and inspection helpers so flows, state and branching decisions are observable during development and debugging.

## [0.1.1] - 2024-07-09

- Bugfix step model name:
  Preserve the original i18n_key value when overriding ActiveModel::Model.model_name

    eg.

        RootModule::SubModule::SomeStep # should produce the i18n key
        :root_module/sub_module/some_step

    This will have side effects for everyone that is using 0.1.0

    It is recommend to update the translations to use the full model name of
    your steps.

## [0.1.0] - 2024-06-11

- Initial release
