# Wizard Documentation

**Structure Type:** `graph`
**Generated:** 2025-12-04T08:04:13Z
**Processor:** DfE::Wizard::StepsProcessor


## Overview

| Metric                           | Value                       |
|----------------------------------|-----------------------------|
| Total Steps                      | 5              |
| Simple Transitions               | 0       |
| Conditional Transitions          | 0         |
| Multiple Conditional Transitions | 0        |
| Custom Branching Transitions     | 0       |
| **Total Transitions**            | **0**    |


## Root Entry Point (Fixed)

**Entry Point:** `name_and_date_of_birth`

All users start at this step. No conditional logic applies.


## Wizard Flow

```
[:name_and_date_of_birth]
  ↓
[:nationality]
├─→ [:right_to_work_or_study] Non-UK/Non-Irish (✓)
│ ├─→ [:immigration_status] Right to work or study? (✓)
│ │   ↓
│ │ [:review]
│ └─→ [:review] Right to work or study? (✗)
└─→ [:review] Non-UK/Non-Irish (✗)
```

### Legend

- **━━** Simple edge (linear progression, no condition)
- **─┬─** Conditional edge (if/else decision point)
- **┼** Multiple conditional edge (N-way branching)
- **⊕** Custom branching edge (complex status-driven routing)


## Steps Inventory

| Step ID | Label | Class |
|---------|-------|-------|
| `name_and_date_of_birth` | Name And Date Of Birth | `Steps::NameAndDateOfBirth` |
| `nationality` | Nationality | `Steps::Nationality` |
| `right_to_work_or_study` | Right To Work Or Study | `Steps::RightToWorkOrStudy` |
| `immigration_status` | Immigration Status | `Steps::ImmigrationStatus` |
| `review` | Review | `Steps::Review` |


## Detailed Step Specifications

### Step: `name_and_date_of_birth`

**Label:** Name And Date Of Birth
**Class:** `Steps::NameAndDateOfBirth`
**Entry Point:** ✓ Yes
**Exit Points:** `nationality`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `first_name` | `ActiveModel::Type::String` | ✗ |  |
| `last_name` | `ActiveModel::Type::String` | ✗ |  |
| `date_of_birth` | `ActiveModel::Type::Date` | ✗ |  |

#### Validations

- **first_name** (`presence`): 
- **last_name** (`presence`): 
- **date_of_birth** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `nationality`

**Label:** Nationality
**Class:** `Steps::Nationality`
**Entry Point:** ✗ No
**Exit Points:** `review`, `right_to_work_or_study`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `nationalities` | `ActiveModel::Type::Value` | ✗ |  |
| `other_nationality` | `ActiveModel::Type::String` | ✗ |  |

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `right_to_work_or_study`

**Label:** Right To Work Or Study
**Class:** `Steps::RightToWorkOrStudy`
**Entry Point:** ✗ No
**Exit Points:** `immigration_status`, `review`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `right_to_work_or_study` | `ActiveModel::Type::String` | ✗ |  |
| `visa_expiry` | `ActiveModel::Type::String` | ✗ |  |
| `visa_type` | `ActiveModel::Type::String` | ✗ |  |

#### Validations

- **right_to_work_or_study** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `immigration_status`

**Label:** Immigration Status
**Class:** `Steps::ImmigrationStatus`
**Entry Point:** ✗ No
**Exit Points:** `review`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `status` | `ActiveModel::Type::String` | ✗ |  |
| `other_status` | `ActiveModel::Type::String` | ✗ |  |

#### Validations

- **status** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `review`

**Label:** Review
**Class:** `Steps::Review`
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

This wizard contains **4 transitions** across 4 types:

- **2 simple transitions** – Linear progression (unconditional)
- **2 conditional transitions** – If/else branching logic
- **0 multiple conditional transitions** – N-way branching
- **0 custom branching transitions** – Complex status-driven routing


### Simple Transitions

Simple transitions allow linear, unconditional progression from one step to the next.

| From | To | Behavior |
|------|-----|----------|
| `name_and_date_of_birth` | `nationality` | Always proceeds (no condition) |
| `immigration_status` | `review` | Always proceeds (no condition) |


### Conditional Transitions (If/Else)


Conditional transitions split the flow into two branches based on a predicate evaluation.


#### `nationality` → `right_to_work_or_study` OR `review`

| Property | Value |
|----------|-------|
| From | `nationality` |
| Condition | `Non-UK/Non-Irish` |
| Then (if true) | `right_to_work_or_study` |
| Else (if false) | `review` |

**Flow Logic:**

Evaluates the predicate `Non-UK/Non-Irish`:
- If condition is **true** → proceed to `right_to_work_or_study`
- If condition is **false** → proceed to `review`


#### `right_to_work_or_study` → `immigration_status` OR `review`

| Property | Value |
|----------|-------|
| From | `right_to_work_or_study` |
| Condition | `Right to work or study?` |
| Then (if true) | `immigration_status` |
| Else (if false) | `review` |

**Flow Logic:**

Evaluates the predicate `Right to work or study?`:
- If condition is **true** → proceed to `immigration_status`
- If condition is **false** → proceed to `review`
"


## Wizard Statistics

| Metric | Count |
|--------|-------|
| Total Steps | 5 |
| Simple Transitions | 0 |
| Conditional Transitions | 0 |
| Multiple Conditional Transitions | 0 |
| Custom Branching Transitions | 0 |
| **Total Transitions** | **4** |


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
  :root_step: "name_and_date_of_birth",
  :steps: {
    :name_and_date_of_birth: {
      :class: "Steps::NameAndDateOfBirth",
      :label: "Name And Date Of Birth",
      :attributes: [
        {
          :name: "first_name",
          :type: "ActiveModel::Type::String"
        },
        {
          :name: "last_name",
          :type: "ActiveModel::Type::String"
        },
        {
          :name: "date_of_birth",
          :type: "ActiveModel::Type::Date"
        }
      ],
      :validators: [
        {
          :name: "first_name",
          :class: "ActiveModel::Validations::PresenceValidator",
          :type: "presence",
          :message: null
        },
        {
          :name: "last_name",
          :class: "ActiveModel::Validations::PresenceValidator",
          :type: "presence",
          :message: null
        },
        {
          :name: "date_of_birth",
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
    :nationality: {
      :class: "Steps::Nationality",
      :label: "Nationality",
      :attributes: [
        {
          :name: "nationalities",
          :type: "ActiveModel::Type::Value"
        },
        {
          :name: "other_nationality",
          :type: "ActiveModel::Type::String"
        }
      ],
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
    },
    :right_to_work_or_study: {
      :class: "Steps::RightToWorkOrStudy",
      :label: "Right To Work Or Study",
      :attributes: [
        {
          :name: "right_to_work_or_study",
          :type: "ActiveModel::Type::String"
        },
        {
          :name: "visa_expiry",
          :type: "ActiveModel::Type::String"
        },
        {
          :name: "visa_type",
          :type: "ActiveModel::Type::String"
        }
      ],
      :validators: [
        {
          :name: "right_to_work_or_study",
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
    :immigration_status: {
      :class: "Steps::ImmigrationStatus",
      :label: "Immigration Status",
      :attributes: [
        {
          :name: "status",
          :type: "ActiveModel::Type::String"
        },
        {
          :name: "other_status",
          :type: "ActiveModel::Type::String"
        }
      ],
      :validators: [
        {
          :name: "status",
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
    :review: {
      :class: "Steps::Review",
      :label: "Review",
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
      :from: "name_and_date_of_birth",
      :to: "nationality",
      :type: "simple",
      :label: null
    },
    {
      :from: "immigration_status",
      :to: "review",
      :type: "simple",
      :label: null
    },
    {
      :from: "nationality",
      :then: "right_to_work_or_study",
      :else: "review",
      :type: "conditional",
      :label: "Non-UK/Non-Irish"
    },
    {
      :from: "right_to_work_or_study",
      :then: "immigration_status",
      :else: "review",
      :type: "conditional",
      :label: "Right to work or study?"
    }
  ],
  :counts: {
    :steps: 5,
    :simple_edges: 2,
    :conditional_edges: 2,
    :multiple_conditional_edges: 0,
    :custom_branching_edges: 0
  },
  :wizard_name: "Personal information wizard"
}
```

**Note:** This is the unified metadata format consumed by all documentation formatters.
