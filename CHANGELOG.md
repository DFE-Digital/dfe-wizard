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
