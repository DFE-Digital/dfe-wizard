# Wizard Documentation

**Structure Type:** `graph`
**Generated:** 2025-12-22T07:03:20Z
**Processor:** DfE::Wizard::StepsProcessor


## Overview

| Metric                           | Value                       |
|----------------------------------|-----------------------------|
| Total Steps                      | 6              |
| Simple Transitions               | 0       |
| Conditional Transitions          | 0         |
| Multiple Conditional Transitions | 0        |
| Custom Branching Transitions     | 0       |
| **Total Transitions**            | **0**    |


## Root Entry Points (Dynamic)

This wizard uses conditional root logic. Users may enter at different steps based on runtime state evaluation.

### Possible Entry Points

- `add_a_level_to_a_list`
- `what_a_level_is_required`

**Determination:** Evaluated at initialization based on wizard state. See "Conditional Root Logic" section for details on which conditions route to which entry points.


## Wizard Flow

```
[:add_a_level_to_a_list]
├─→ [:what_a_level_is_required] Add another A-level? (✓)
│   ↓
│ [:add_a_level_to_a_list]
└─→ [:consider_pending_a_level] Add another A-level? (✗)
    ↓
  [:a_level_equivalencies]
    ↓
  [:course_edit]
[:what_a_level_is_required]
  ↓
[:add_a_level_to_a_list]
├─→ [:what_a_level_is_required] Add another A-level? (✓)
└─→ [:consider_pending_a_level] Add another A-level? (✗)
    ↓
  [:a_level_equivalencies]
    ↓
  [:course_edit]
```

### Legend

- **━━** Simple edge (linear progression, no condition)
- **─┬─** Conditional edge (if/else decision point)
- **┼** Multiple conditional edge (N-way branching)
- **⊕** Custom branching edge (complex status-driven routing)


## Steps Inventory

| Step ID | Label | Class |
|---------|-------|-------|
| `what_a_level_is_required` | What A Level Is Required | `Steps::WhatALevelIsRequired` |
| `add_a_level_to_a_list` | Add A Level To A List | `Steps::AddALevelToAList` |
| `remove_a_level_subject_confirmation` | Remove A Level Subject Confirmation | `Steps::RemoveALevelSubjectConfirmation` |
| `consider_pending_a_level` | Consider Pending A Level | `Steps::ConsiderPendingALevel` |
| `a_level_equivalencies` | A Level Equivalencies | `Steps::ALevelEquivalencies` |
| `course_edit` | Course Edit | `DfE::Wizard::Core::Redirect` |


## Detailed Step Specifications

### Step: `what_a_level_is_required`

**Label:** What A Level Is Required
**Class:** `Steps::WhatALevelIsRequired`
**Entry Point:** ✓ Yes
**Exit Points:** `add_a_level_to_a_list`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `uuid` | `ActiveModel::Type::Value` | ✗ |  |
| `subject` | `ActiveModel::Type::Value` | ✗ |  |
| `other_subject` | `ActiveModel::Type::Value` | ✗ |  |
| `minimum_grade_required` | `ActiveModel::Type::Value` | ✗ |  |

#### Validations

- **subject** (`presence`): 
- **other_subject** (`presence`): 
- **minimum_grade_required** (`length`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `create_a_level` | CreateALevel operation |


### Step: `add_a_level_to_a_list`

**Label:** Add A Level To A List
**Class:** `Steps::AddALevelToAList`
**Entry Point:** ✓ Yes
**Exit Points:** `consider_pending_a_level`, `what_a_level_is_required`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `add_another_a_level` | `ActiveModel::Type::Value` | ✗ |  |
| `subjects` | `ActiveModel::Type::Value` | ✗ |  |

#### Validations

- **add_another_a_level** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `remove_a_level_subject_confirmation`

**Label:** Remove A Level Subject Confirmation
**Class:** `Steps::RemoveALevelSubjectConfirmation`
**Entry Point:** ✗ No
**Exit Points:** `add_a_level_to_a_list`, `course_edit`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `uuid` | `ActiveModel::Type::Value` | ✗ |  |
| `subject` | `ActiveModel::Type::Value` | ✗ |  |
| `other_subject` | `ActiveModel::Type::Value` | ✗ |  |
| `confirmation` | `ActiveModel::Type::Value` | ✗ |  |

#### Validations

- **uuid** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `remove_a_level_subject_confirmation` | RemoveALevelSubjectConfirmation operation |


### Step: `consider_pending_a_level`

**Label:** Consider Pending A Level
**Class:** `Steps::ConsiderPendingALevel`
**Entry Point:** ✗ No
**Exit Points:** `a_level_equivalencies`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `pending_a_level` | `ActiveModel::Type::Value` | ✗ |  |

#### Validations

- **pending_a_level** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `a_level_equivalencies`

**Label:** A Level Equivalencies
**Class:** `Steps::ALevelEquivalencies`
**Entry Point:** ✗ No
**Exit Points:** `course_edit`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `accept_a_level_equivalency` | `ActiveModel::Type::Value` | ✗ |  |
| `additional_a_level_equivalencies` | `ActiveModel::Type::Value` | ✗ |  |

#### Validations

- **accept_a_level_equivalency** (`presence`): 
- **additional_a_level_equivalencies** (`words_count`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `course_edit`

**Label:** Course Edit
**Class:** `DfE::Wizard::Core::Redirect`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


## Transitions Reference

This wizard contains **5 transitions** across 4 types:

- **3 simple transitions** – Linear progression (unconditional)
- **2 conditional transitions** – If/else branching logic
- **0 multiple conditional transitions** – N-way branching
- **0 custom branching transitions** – Complex status-driven routing


### Simple Transitions

Simple transitions allow linear, unconditional progression from one step to the next.

| From | To | Behavior |
|------|-----|----------|
| `what_a_level_is_required` | `add_a_level_to_a_list` | Always proceeds (no condition) |
| `consider_pending_a_level` | `a_level_equivalencies` | Always proceeds (no condition) |
| `a_level_equivalencies` | `course_edit` | Always proceeds (no condition) |


### Conditional Transitions (If/Else)


Conditional transitions split the flow into two branches based on a predicate evaluation.


#### `add_a_level_to_a_list` → `what_a_level_is_required` OR `consider_pending_a_level`

| Property | Value |
|----------|-------|
| From | `add_a_level_to_a_list` |
| Condition | `Add another A-level?` |
| Then (if true) | `what_a_level_is_required` |
| Else (if false) | `consider_pending_a_level` |

**Flow Logic:**

Evaluates the predicate `Add another A-level?`:
- If condition is **true** → proceed to `what_a_level_is_required`
- If condition is **false** → proceed to `consider_pending_a_level`


#### `remove_a_level_subject_confirmation` → `add_a_level_to_a_list` OR `course_edit`

| Property | Value |
|----------|-------|
| From | `remove_a_level_subject_confirmation` |
| Condition | `Has remaining A-levels?` |
| Then (if true) | `add_a_level_to_a_list` |
| Else (if false) | `course_edit` |

**Flow Logic:**

Evaluates the predicate `Has remaining A-levels?`:
- If condition is **true** → proceed to `add_a_level_to_a_list`
- If condition is **false** → proceed to `course_edit`
"


## Wizard Statistics

| Metric | Count |
|--------|-------|
| Total Steps | 6 |
| Simple Transitions | 0 |
| Conditional Transitions | 0 |
| Multiple Conditional Transitions | 0 |
| Custom Branching Transitions | 0 |
| **Total Transitions** | **5** |


## Example User Journeys

### Journey 1: Typical Path

```
1. [Entry]  Entry Step
2. [Linear] Step A
3. [Cond]   Step B or C (conditional)
4. [N-way]  Step D (branching)
5. [Exit]   Terminal Step
```

### Journey 2: Alternative Path

```
1. [Entry]  Entry Step (alternate)
2. [Linear] Step A
3. [Status] Different terminal step based on status
```

**Note:** Actual journeys depend on wizard state transitions and predicates.


## Raw Metadata

```json
{
  :structure_type: "graph",
  :root_step: [
    "add_a_level_to_a_list",
    "what_a_level_is_required"
  ],
  :steps: {
    :what_a_level_is_required: {
      :class: "Steps::WhatALevelIsRequired",
      :label: "What A Level Is Required",
      :attributes: [
        {
          :name: "uuid",
          :type: "ActiveModel::Type::Value"
        },
        {
          :name: "subject",
          :type: "ActiveModel::Type::Value"
        },
        {
          :name: "other_subject",
          :type: "ActiveModel::Type::Value"
        },
        {
          :name: "minimum_grade_required",
          :type: "ActiveModel::Type::Value"
        }
      ],
      :validators: [
        {
          :name: "subject",
          :class: "ActiveModel::Validations::PresenceValidator",
          :type: "presence",
          :message: null
        },
        {
          :name: "other_subject",
          :class: "ActiveModel::Validations::PresenceValidator",
          :type: "presence",
          :message: null
        },
        {
          :name: "minimum_grade_required",
          :class: "ActiveModel::Validations::LengthValidator",
          :type: "length",
          :message: null
        }
      ],
      :operations: [
        {
          :name: "create_a_level",
          :description: "CreateALevel operation"
        }
      ]
    },
    :add_a_level_to_a_list: {
      :class: "Steps::AddALevelToAList",
      :label: "Add A Level To A List",
      :attributes: [
        {
          :name: "add_another_a_level",
          :type: "ActiveModel::Type::Value"
        },
        {
          :name: "subjects",
          :type: "ActiveModel::Type::Value"
        }
      ],
      :validators: [
        {
          :name: "add_another_a_level",
          :class: "ActiveModel::Validations::PresenceValidator",
          :type: "presence",
          :message: null
        }
      ],
      :operations: [
        {
          :name: "validate",
          :description: "Validate operation"
        },
        {
          :name: "persist",
          :description: "Persist operation"
        }
      ]
    },
    :remove_a_level_subject_confirmation: {
      :class: "Steps::RemoveALevelSubjectConfirmation",
      :label: "Remove A Level Subject Confirmation",
      :attributes: [
        {
          :name: "uuid",
          :type: "ActiveModel::Type::Value"
        },
        {
          :name: "subject",
          :type: "ActiveModel::Type::Value"
        },
        {
          :name: "other_subject",
          :type: "ActiveModel::Type::Value"
        },
        {
          :name: "confirmation",
          :type: "ActiveModel::Type::Value"
        }
      ],
      :validators: [
        {
          :name: "uuid",
          :class: "ActiveModel::Validations::PresenceValidator",
          :type: "presence",
          :message: null
        }
      ],
      :operations: [
        {
          :name: "remove_a_level_subject_confirmation",
          :description: "RemoveALevelSubjectConfirmation operation"
        }
      ]
    },
    :consider_pending_a_level: {
      :class: "Steps::ConsiderPendingALevel",
      :label: "Consider Pending A Level",
      :attributes: [
        {
          :name: "pending_a_level",
          :type: "ActiveModel::Type::Value"
        }
      ],
      :validators: [
        {
          :name: "pending_a_level",
          :class: "ActiveModel::Validations::PresenceValidator",
          :type: "presence",
          :message: null
        }
      ],
      :operations: [
        {
          :name: "validate",
          :description: "Validate operation"
        },
        {
          :name: "persist",
          :description: "Persist operation"
        }
      ]
    },
    :a_level_equivalencies: {
      :class: "Steps::ALevelEquivalencies",
      :label: "A Level Equivalencies",
      :attributes: [
        {
          :name: "accept_a_level_equivalency",
          :type: "ActiveModel::Type::Value"
        },
        {
          :name: "additional_a_level_equivalencies",
          :type: "ActiveModel::Type::Value"
        }
      ],
      :validators: [
        {
          :name: "accept_a_level_equivalency",
          :class: "ActiveModel::Validations::PresenceValidator",
          :type: "presence",
          :message: null
        },
        {
          :name: "additional_a_level_equivalencies",
          :class: "WordsCountValidator",
          :type: "words_count",
          :message: null
        }
      ],
      :operations: [
        {
          :name: "validate",
          :description: "Validate operation"
        },
        {
          :name: "persist",
          :description: "Persist operation"
        }
      ]
    },
    :course_edit: {
      :class: "DfE::Wizard::Core::Redirect",
      :label: "Course Edit",
      :attributes: [],
      :validators: [],
      :operations: [
        {
          :name: "validate",
          :description: "Validate operation"
        },
        {
          :name: "persist",
          :description: "Persist operation"
        }
      ]
    }
  },
  :transitions: [
    {
      :from: "what_a_level_is_required",
      :to: "add_a_level_to_a_list",
      :type: "simple",
      :label: null
    },
    {
      :from: "consider_pending_a_level",
      :to: "a_level_equivalencies",
      :type: "simple",
      :label: null
    },
    {
      :from: "a_level_equivalencies",
      :to: "course_edit",
      :type: "simple",
      :label: null
    },
    {
      :from: "add_a_level_to_a_list",
      :when: "add_another_a_level?",
      :then: "what_a_level_is_required",
      :else: "consider_pending_a_level",
      :type: "conditional",
      :label: "Add another A-level?"
    },
    {
      :from: "remove_a_level_subject_confirmation",
      :when: "has_remaining_a_levels?",
      :then: "add_a_level_to_a_list",
      :else: "course_edit",
      :type: "conditional",
      :label: "Has remaining A-levels?"
    }
  ],
  :counts: {
    :steps: 6,
    :simple_edges: 3,
    :conditional_edges: 2,
    :multiple_conditional_edges: 0,
    :custom_branching_edges: 0
  },
  :wizard_name: "A levels requirements wizard"
}
```

**Note:** This is the unified metadata format consumed by all documentation formatters.
