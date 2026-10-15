## [Unreleased]

### Added

- **`DfE::Wizard::Error`** is a module included by every error the gem
  raises on purpose, so `rescue DfE::Wizard::Error` catches them all.
  **`DfE::Wizard::InvalidGraph`** (an `ArgumentError`) is raised when a
  graph breaks a sub-wizard rule.
- **Sub-wizards: `graph.add_sub_wizard :id, steps: [...]`** names a group of
  steps in a Graph wizard. The steps stay ordinary nodes, so every path API
  is unchanged. `exit_to:` sends the steps' open exits (no edge, no
  `default:`, a nil branch) to one node. `steps_processor.sub_wizards` and
  `steps_processor.unit_for(step_id)` return the units. Graph only: other
  processors return `{}` and nil.
- **Sub-wizard classes: `graph.add_sub_wizard :id, SubWizardClass`.** The
  class (`extend DfE::Wizard::SubWizard`) draws its own nodes and edges into
  the parent graph and lists the state store methods it calls with `uses`.
  It gets a restricted graph: nodes and edges only, edges only from its own
  nodes, and every predicate a Symbol listed in `uses`. Both forms give the
  same unit, so a unit can move between them without other changes.
- **Draw-time sub-wizard checks.** Each draw raises `InvalidGraph` when a
  path leaves a sub-wizard and comes back, a sub-wizard exits to more than
  one node, a step is in two sub-wizards, a sub-wizard id is a node id, or
  an explicit step is not a node. Graphs with no sub-wizards skip them.
- **`DfE::Wizard::Test::SubWizardHarness`** runs one sub-wizard class on its
  own, with a real state store or a stub store built from `uses`. The
  existing matchers work on `harness.wizard`. A step that calls an app
  wizard method raises `NoMethodError` there.
- **`wizard.changeset`** keeps gem state beside the answers, under one
  reserved top-level key, `_dfe_wizard`, written through the state store.
  `changeset.answers` and `changeset.answer_changes_since(snapshot)` compare
  answers after a JSON round trip, so values read back from any repository
  compare equal. A `Repository::Model` (or subclass), or a state store
  built without a repository, cannot hold one.
- **`graph.check_answers :node`** marks the check answers page and turns on
  change journeys (below). **`depends_on:`** on `add_node` and
  `add_sub_wizard` names the answers whose change queues that unit.
  `steps_processor.unit(unit_id)` and `steps_processor.check_answers_step`
  read them. Draws raise `InvalidGraph` for a check answers node that is not
  a node, is in a sub-wizard or has `depends_on`, for a `depends_on` name
  that is not a step attribute, and for a step attribute named
  `_dfe_wizard`.
- **Change journeys.** In a wizard that declares `graph.check_answers`, a
  "Change" link (`return_to_review=<step>`, as in 1.0) starts a journey on
  its GET: call `wizard.journey_start_redirect` and redirect to the path it
  returns. The journey opens on the named step (or, when it is not on the
  path, on its unit's first step on the path), shows the rest of the
  step's unit (a sub-wizard, or one step), then returns to check answers.
  Back goes to the previous step of the unit, and from the step it opened
  on to check answers. A save on a step outside the journey uses 1.0
  navigation. During a journey, the wizard picks the next and previous step
  before any `before_next_step` or `before_previous_step` callback runs.
- **Chaining.** When a unit in a change journey ends, the journey shows the
  first later unit on the path whose `depends_on` names an answer that
  changed since the journey started, then the next, and returns to check
  answers when none is left. Back crosses into the unit shown before.
  Saving a unit the user went Back into makes it current again, so a later
  unit is asked again if its dependency still changed.
- **Edits of saved records.** Build the wizard with `record:` and call
  `wizard.start_edit(unit:, caller:)` at the entry point: it seeds the
  changeset with `wizard.mapper.to_answers(record)` (`DfE::Wizard::Mapper`)
  and starts a change journey for the unit, open on the step when `unit:`
  is a step id. Back from the step the edit opened on and the end of the
  journey go to the caller URL. The save that ends the
  journey runs the operations registered with `builder.on_commit(use:)`,
  unless nothing changed or the record is stale, then discards the
  changeset; `wizard.commit_result` holds the status (`:committed`,
  `:unchanged`, `:stale`, `:failed`) and the errors.
  `wizard.step_accessible?` and `wizard.redirect_step` guard the steps of
  an edit.
- **Changeset edit fields:** `changeset.seed!`, `seed`, `seed_updated_at`,
  `edit?`, `diff` and `diff?` (answers on the path that differ from the
  seed, compared in JSON form, with a Time in UTC to the microsecond,
  and returned as the store holds them, so a Date or a Struct answer
  reaches the commit operation unchanged),
  `stale?(record)` and `discard!` (only this changeset's data).
- **`wizard.answers_on_path`** returns the answers of the steps on
  `full_path`.
- **`Repository::Base#delete_state`** removes only this state's data, for
  `changeset.discard!`. It calls `delete_data`; `Repository::Redis`
  overrides it to remove only this `state_key`'s state.
- **`Repository::InMemory#delete_data`** removes all data, as `clear`
  does.
- **Edit errors:** `DfE::Wizard::NotCallable`, `ChangesetMismatch`,
  `ChangesetExpired` and `StepNotAccessible`.
- **Edit review: `graph.edit_review :node`.** An edit with a change ends on
  this node instead of committing, unless the node's `skip_when` holds. The
  commit runs when the user saves the node; Back goes to the last step
  shown. Drafts never show it. `steps_processor.edit_review_step` returns
  the node, and `steps_processor.skipped?(step_id)` evaluates a node's
  `skip_when`.
- **`changeset.edit_unit`** returns the id of the unit the edit started
  with (for a step in a sub-wizard, the sub-wizard id).
  `changeset.caller_url` is now public.
- **`wizard.full_path`** returns every step from the root to the end of the
  graph over the current answers, without stopping at the current step. It
  stops before a Redirect node, an id that is not a node, or a repeated step.
  Needs `StepsProcessor::Graph`; other processors raise `NotImplementedError`.
  `flow_path`, `path_traversal` and `dfs_path` are unchanged.
- **`wizard.change_journey(:attr)`** returns the units whose `depends_on`
  names the answer, in the order the graph declares them. It is a static
  view, for docs and tests. `steps_processor.change_journeys` returns them
  for every answer. Graph only: other processors return `{}`.

### Changed

- **The graph is drawn once per wizard instance.** The gem now caches the
  result of `steps_processor` and uses it at every internal call site.
  `unflatten_state` builds its attribute-to-step map once per call. Check
  answers on a 14-step wizard went from 303 draws to 1. The public
  `steps_processor` is unchanged. A draw block that chooses nodes, edges
  or the root with a Ruby `if` on answers must move that choice into a
  predicate, `skip_when` or `conditional_root`.
- `state_store=` is now an explicit writer. It drops the cached graph, the
  default steps operator, the changeset and the hydrated steps, and gives
  a store set after `new` its attribute readers.
- **The wizard sets `state_store.wizard`** in `new` and in `state_store=`,
  so state store methods can read context (for example the provider)
  through the wizard. In 1.0 the attribute existed but was never set.
- A test that stubs a Symbol predicate or a Symbol callback after the wizard
  is built no longer sees the stub, because the graph bound the method when
  it was drawn. Stub before building the wizard, or use a lambda predicate.
- `raw_data`, `data` and the metadata readers never return `_dfe_wizard`.
- `StateStore.new` without `repository:` still uses a new InMemory
  repository, and `default_repository?` reports it. Passing
  `repository: nil` now gives that fallback instead of a nil repository.

### Fixed

- **`Repository::Redis#write` now replaces an existing key.** In 1.0 a second
  write of the same key kept the old value on read, because the stored JSON
  held the key twice. This applies with and without a `state_key`, and with
  encryption.
- **`Repository::Session#delete_data` (and so `clear`) with a `state_key`**
  now removes the state when it is the only one under the key. In 1.0 it
  left it in place.

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
- `DfE::Wizard::VERSION` is available after `require 'dfe/wizard'`. It was
  previously declared as an autoload pointing at a file that defines
  `Dfe::Wizard::VERSION` (lowercase `e`), so neither spelling resolved from the
  loaded library. The lowercase constant is retained as an alias.

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
