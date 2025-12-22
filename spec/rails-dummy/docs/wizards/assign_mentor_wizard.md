# Wizard Documentation

**Structure Type:** `graph`
**Generated:** 2025-12-22T07:03:20Z
**Processor:** DfE::Wizard::StepsProcessor


## Overview

| Metric                           | Value                       |
|----------------------------------|-----------------------------|
| Total Steps                      | 4              |
| Simple Transitions               | 0       |
| Conditional Transitions          | 0         |
| Multiple Conditional Transitions | 0        |
| Custom Branching Transitions     | 0       |
| **Total Transitions**            | **0**    |


## Root Entry Point (Fixed)

**Entry Point:** `who_will_be_the_mentor`

All users start at this step. No conditional logic applies.


## Wizard Flow

```
[:who_will_be_the_mentor]
  ↓
[:can_receive_mentor_training]
├─→ [:which_lead_provider] LP provides? (✓)
│   ↓
│ [:confirmation]
└─→ [:confirmation] LP provides? (✗)
```

### Legend

- **━━** Simple edge (linear progression, no condition)
- **─┬─** Conditional edge (if/else decision point)
- **┼** Multiple conditional edge (N-way branching)
- **⊕** Custom branching edge (complex status-driven routing)


## Steps Inventory

| Step ID | Label | Class |
|---------|-------|-------|
| `who_will_be_the_mentor` | Who Will Be The Mentor | `Steps::WhoWillBeTheMentor` |
| `can_receive_mentor_training` | Can Receive Mentor Training | `Steps::CanReceiveMentorTraining` |
| `which_lead_provider` | Which Lead Provider | `Steps::WhichLeadProvider` |
| `confirmation` | Confirmation | `Steps::Confirmation` |


## Detailed Step Specifications

### Step: `who_will_be_the_mentor`

**Label:** Who Will Be The Mentor
**Class:** `Steps::WhoWillBeTheMentor`
**Entry Point:** ✓ Yes
**Exit Points:** `can_receive_mentor_training`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `mentor_id` | `ActiveModel::Type::Integer` | ✗ |  |

#### Validations

- **mentor_id** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `can_receive_mentor_training`

**Label:** Can Receive Mentor Training
**Class:** `Steps::CanReceiveMentorTraining`
**Entry Point:** ✗ No
**Exit Points:** `confirmation`, `which_lead_provider`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `lp_will_provide` | `ActiveModel::Type::String` | ✗ |  |

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `which_lead_provider`

**Label:** Which Lead Provider
**Class:** `Steps::WhichLeadProvider`
**Entry Point:** ✗ No
**Exit Points:** `confirmation`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `lead_provider_id` | `ActiveModel::Type::Integer` | ✗ |  |

#### Validations

- **lead_provider_id** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `confirmation`

**Label:** Confirmation
**Class:** `Steps::Confirmation`
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

This wizard contains **3 transitions** across 4 types:

- **2 simple transitions** – Linear progression (unconditional)
- **1 conditional transitions** – If/else branching logic
- **0 multiple conditional transitions** – N-way branching
- **0 custom branching transitions** – Complex status-driven routing


### Simple Transitions

Simple transitions allow linear, unconditional progression from one step to the next.

| From | To | Behavior |
|------|-----|----------|
| `who_will_be_the_mentor` | `can_receive_mentor_training` | Always proceeds (no condition) |
| `which_lead_provider` | `confirmation` | Always proceeds (no condition) |


### Conditional Transitions (If/Else)


Conditional transitions split the flow into two branches based on a predicate evaluation.


#### `can_receive_mentor_training` → `which_lead_provider` OR `confirmation`

| Property | Value |
|----------|-------|
| From | `can_receive_mentor_training` |
| Condition | `LP provides?` |
| Then (if true) | `which_lead_provider` |
| Else (if false) | `confirmation` |

**Flow Logic:**

Evaluates the predicate `LP provides?`:
- If condition is **true** → proceed to `which_lead_provider`
- If condition is **false** → proceed to `confirmation`
"


## Wizard Statistics

| Metric | Count |
|--------|-------|
| Total Steps | 4 |
| Simple Transitions | 0 |
| Conditional Transitions | 0 |
| Multiple Conditional Transitions | 0 |
| Custom Branching Transitions | 0 |
| **Total Transitions** | **3** |


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
  :root_step: "who_will_be_the_mentor",
  :steps: {
    :who_will_be_the_mentor: {
      :class: "Steps::WhoWillBeTheMentor",
      :label: "Who Will Be The Mentor",
      :attributes: [
        {
          :name: "mentor_id",
          :type: "ActiveModel::Type::Integer"
        }
      ],
      :validators: [
        {
          :name: "mentor_id",
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
    :can_receive_mentor_training: {
      :class: "Steps::CanReceiveMentorTraining",
      :label: "Can Receive Mentor Training",
      :attributes: [
        {
          :name: "lp_will_provide",
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
    :which_lead_provider: {
      :class: "Steps::WhichLeadProvider",
      :label: "Which Lead Provider",
      :attributes: [
        {
          :name: "lead_provider_id",
          :type: "ActiveModel::Type::Integer"
        }
      ],
      :validators: [
        {
          :name: "lead_provider_id",
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
    :confirmation: {
      :class: "Steps::Confirmation",
      :label: "Confirmation",
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
      :from: "who_will_be_the_mentor",
      :to: "can_receive_mentor_training",
      :type: "simple",
      :label: null
    },
    {
      :from: "which_lead_provider",
      :to: "confirmation",
      :type: "simple",
      :label: null
    },
    {
      :from: "can_receive_mentor_training",
      :when: "lead_provider_will_not_provide?",
      :then: "which_lead_provider",
      :else: "confirmation",
      :type: "conditional",
      :label: "LP provides?"
    }
  ],
  :counts: {
    :steps: 4,
    :simple_edges: 2,
    :conditional_edges: 1,
    :multiple_conditional_edges: 0,
    :custom_branching_edges: 0
  },
  :wizard_name: "Assign mentor wizard"
}
```

**Note:** This is the unified metadata format consumed by all documentation formatters.
