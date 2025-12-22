# Wizard Documentation

**Structure Type:** `graph`
**Generated:** 2025-12-22T07:03:20Z
**Processor:** DfE::Wizard::StepsProcessor


## Overview

| Metric                           | Value                       |
|----------------------------------|-----------------------------|
| Total Steps                      | 13              |
| Simple Transitions               | 0       |
| Conditional Transitions          | 0         |
| Multiple Conditional Transitions | 0        |
| Custom Branching Transitions     | 0       |
| **Total Transitions**            | **0**    |


## Root Entry Point (Fixed)

**Entry Point:** `do_you_know_the_course`

All users start at this step. No conditional logic applies.


## Wizard Flow

```
[:do_you_know_the_course]
├─→ [:provider_selection]  (✓)
│   ↓
│ [:course_selection]
│ ├─→ [:reached_reapplication_limit]
│ ├─→ [:duplicate_course_selection]
│ ├─→ [:closed_course_selection]
│ ├─→ [:full_course_selection]
│ ├─→ [:review]
│ │   ↓
│ │ [:confirm_apply]
│ │   ↓
│ │ [:application_choices_list]
│ ├─→ [:study_mode_selection]
│ │ ├─→ [:review]  (✓)
│ │ └─→ [:school_selection]  (✗)
│ │     ↓
│ │   [:review]
│ └─→ [:school_selection]
└─→ [:go_to_find_explanation]  (✗)
```

### Legend

- **━━** Simple edge (linear progression, no condition)
- **─┬─** Conditional edge (if/else decision point)
- **┼** Multiple conditional edge (N-way branching)
- **⊕** Custom branching edge (complex status-driven routing)


## Steps Inventory

| Step ID | Label | Class |
|---------|-------|-------|
| `do_you_know_the_course` | Do You Know The Course | `Steps::DoYouKnowTheCourse` |
| `go_to_find_explanation` | Go To Find Explanation | `Steps::GoToFindExplanation` |
| `provider_selection` | Provider Selection | `Steps::ProviderSelection` |
| `course_selection` | Course Selection | `Steps::CourseSelection` |
| `reached_reapplication_limit` | Reached Reapplication Limit | `Steps::ReachedReapplicationLimit` |
| `duplicate_course_selection` | Duplicate Course Selection | `Steps::DuplicateCourseSelection` |
| `closed_course_selection` | Closed Course Selection | `Steps::ClosedCourseSelection` |
| `full_course_selection` | Full Course Selection | `Steps::FullCourseSelection` |
| `study_mode_selection` | Study Mode Selection | `Steps::StudyModeSelection` |
| `school_selection` | School Selection | `Steps::SchoolSelection` |
| `review` | Review | `Steps::ApplyReview` |
| `confirm_apply` | Confirm Apply | `Steps::ConfirmApply` |
| `application_choices_list` | Application Choices List | `DfE::Wizard::Core::Redirect` |


## Detailed Step Specifications

### Step: `do_you_know_the_course`

**Label:** Do You Know The Course
**Class:** `Steps::DoYouKnowTheCourse`
**Entry Point:** ✓ Yes
**Exit Points:** `go_to_find_explanation`, `provider_selection`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `know_the_course_to_apply` | `ActiveModel::Type::String` | ✗ |  |

#### Validations

- **know_the_course_to_apply** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `go_to_find_explanation`

**Label:** Go To Find Explanation
**Class:** `Steps::GoToFindExplanation`
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


### Step: `provider_selection`

**Label:** Provider Selection
**Class:** `Steps::ProviderSelection`
**Entry Point:** ✗ No
**Exit Points:** `course_selection`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `course_selection`

**Label:** Course Selection
**Class:** `Steps::CourseSelection`
**Entry Point:** ✗ No
**Exit Points:** `closed_course_selection`, `duplicate_course_selection`, `full_course_selection`, `reached_reapplication_limit`, `review`, `school_selection`, `study_mode_selection`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `create_application_choice` | CreateApplicationChoice operation |


### Step: `reached_reapplication_limit`

**Label:** Reached Reapplication Limit
**Class:** `Steps::ReachedReapplicationLimit`
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


### Step: `duplicate_course_selection`

**Label:** Duplicate Course Selection
**Class:** `Steps::DuplicateCourseSelection`
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


### Step: `closed_course_selection`

**Label:** Closed Course Selection
**Class:** `Steps::ClosedCourseSelection`
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


### Step: `full_course_selection`

**Label:** Full Course Selection
**Class:** `Steps::FullCourseSelection`
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


### Step: `study_mode_selection`

**Label:** Study Mode Selection
**Class:** `Steps::StudyModeSelection`
**Entry Point:** ✗ No
**Exit Points:** `review`, `school_selection`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `school_selection`

**Label:** School Selection
**Class:** `Steps::SchoolSelection`
**Entry Point:** ✗ No
**Exit Points:** `review`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `update_application_choice_school` | UpdateApplicationChoiceSchool operation |


### Step: `review`

**Label:** Review
**Class:** `Steps::ApplyReview`
**Entry Point:** ✗ No
**Exit Points:** `confirm_apply`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `confirm_apply`

**Label:** Confirm Apply
**Class:** `Steps::ConfirmApply`
**Entry Point:** ✗ No
**Exit Points:** `application_choices_list`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `submit_application_choice` | SubmitApplicationChoice operation |


### Step: `application_choices_list`

**Label:** Application Choices List
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

This wizard contains **7 transitions** across 4 types:

- **4 simple transitions** – Linear progression (unconditional)
- **2 conditional transitions** – If/else branching logic
- **1 multiple conditional transitions** – N-way branching
- **0 custom branching transitions** – Complex status-driven routing


### Simple Transitions

Simple transitions allow linear, unconditional progression from one step to the next.

| From | To | Behavior |
|------|-----|----------|
| `provider_selection` | `course_selection` | Always proceeds (no condition) |
| `school_selection` | `review` | Always proceeds (no condition) |
| `review` | `confirm_apply` | Always proceeds (no condition) |
| `confirm_apply` | `application_choices_list` | Always proceeds (no condition) |


### Conditional Transitions (If/Else)


Conditional transitions split the flow into two branches based on a predicate evaluation.


#### `do_you_know_the_course` → `provider_selection` OR `go_to_find_explanation`

| Property | Value |
|----------|-------|
| From | `do_you_know_the_course` |
| Condition | `Condition` |
| Then (if true) | `provider_selection` |
| Else (if false) | `go_to_find_explanation` |

**Flow Logic:**

Evaluates the predicate `Condition`:
- If condition is **true** → proceed to `provider_selection`
- If condition is **false** → proceed to `go_to_find_explanation`


#### `study_mode_selection` → `review` OR `school_selection`

| Property | Value |
|----------|-------|
| From | `study_mode_selection` |
| Condition | `Condition` |
| Then (if true) | `review` |
| Else (if false) | `school_selection` |

**Flow Logic:**

Evaluates the predicate `Condition`:
- If condition is **true** → proceed to `review`
- If condition is **false** → proceed to `school_selection`
"


### Multiple Conditional Transitions (N-way Branching)


N-way transitions route to different steps based on multiple independent conditions.


#### `course_selection` → Multiple Destinations (7 branches)

| Property | Value |
|----------|-------|
| From | `course_selection` |
| Label | Classification |
| Type | Multiple Conditional (N-way) |
| Default | `study_mode_selection` |

**Branches:**

| Branch | Destination |
|--------|-------------|
|  | `reached_reapplication_limit` |
|  | `duplicate_course_selection` |
|  | `closed_course_selection` |
|  | `full_course_selection` |
|  | `review` |
|  | `study_mode_selection` |
|  | `school_selection` |
| (default, no match) | `study_mode_selection` |
"


## Wizard Statistics

| Metric | Count |
|--------|-------|
| Total Steps | 13 |
| Simple Transitions | 0 |
| Conditional Transitions | 0 |
| Multiple Conditional Transitions | 0 |
| Custom Branching Transitions | 0 |
| **Total Transitions** | **7** |


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
  :root_step: "do_you_know_the_course",
  :steps: {
    :do_you_know_the_course: {
      :class: "Steps::DoYouKnowTheCourse",
      :label: "Do You Know The Course",
      :attributes: [
        {
          :name: "know_the_course_to_apply",
          :type: "ActiveModel::Type::String"
        }
      ],
      :validators: [
        {
          :name: "know_the_course_to_apply",
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
    :go_to_find_explanation: {
      :class: "Steps::GoToFindExplanation",
      :label: "Go To Find Explanation",
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
    },
    :provider_selection: {
      :class: "Steps::ProviderSelection",
      :label: "Provider Selection",
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
    },
    :course_selection: {
      :class: "Steps::CourseSelection",
      :label: "Course Selection",
      :attributes: [],
      :validators: [],
      :operations: [
        {
          :name: "validate",
          :description: "Validate operation"
        },
        {
          :name: "create_application_choice",
          :description: "CreateApplicationChoice operation"
        }
      ]
    },
    :reached_reapplication_limit: {
      :class: "Steps::ReachedReapplicationLimit",
      :label: "Reached Reapplication Limit",
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
    },
    :duplicate_course_selection: {
      :class: "Steps::DuplicateCourseSelection",
      :label: "Duplicate Course Selection",
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
    },
    :closed_course_selection: {
      :class: "Steps::ClosedCourseSelection",
      :label: "Closed Course Selection",
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
    },
    :full_course_selection: {
      :class: "Steps::FullCourseSelection",
      :label: "Full Course Selection",
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
    },
    :study_mode_selection: {
      :class: "Steps::StudyModeSelection",
      :label: "Study Mode Selection",
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
    },
    :school_selection: {
      :class: "Steps::SchoolSelection",
      :label: "School Selection",
      :attributes: [],
      :validators: [],
      :operations: [
        {
          :name: "validate",
          :description: "Validate operation"
        },
        {
          :name: "update_application_choice_school",
          :description: "UpdateApplicationChoiceSchool operation"
        }
      ]
    },
    :review: {
      :class: "Steps::ApplyReview",
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
    },
    :confirm_apply: {
      :class: "Steps::ConfirmApply",
      :label: "Confirm Apply",
      :attributes: [],
      :validators: [],
      :operations: [
        {
          :name: "submit_application_choice",
          :description: "SubmitApplicationChoice operation"
        }
      ]
    },
    :application_choices_list: {
      :class: "DfE::Wizard::Core::Redirect",
      :label: "Application Choices List",
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
      :from: "provider_selection",
      :to: "course_selection",
      :type: "simple",
      :label: null
    },
    {
      :from: "school_selection",
      :to: "review",
      :type: "simple",
      :label: null
    },
    {
      :from: "review",
      :to: "confirm_apply",
      :type: "simple",
      :label: null
    },
    {
      :from: "confirm_apply",
      :to: "application_choices_list",
      :type: "simple",
      :label: null
    },
    {
      :from: "do_you_know_the_course",
      :when: "know_the_course_to_apply?",
      :then: "provider_selection",
      :else: "go_to_find_explanation",
      :type: "conditional",
      :label: null
    },
    {
      :from: "study_mode_selection",
      :when: "completed?",
      :then: "review",
      :else: "school_selection",
      :type: "conditional",
      :label: null
    },
    {
      :from: "course_selection",
      :branches: [
        {
          :when: "reapplication_limit_reached?",
          :then: "reached_reapplication_limit",
          :label: null
        },
        {
          :when: "duplicate_course?",
          :then: "duplicate_course_selection",
          :label: null
        },
        {
          :when: "course_closed?",
          :then: "closed_course_selection",
          :label: null
        },
        {
          :when: "course_unavailable?",
          :then: "full_course_selection",
          :label: null
        },
        {
          :when: "completed?",
          :then: "review",
          :label: null
        },
        {
          :when: "multiple_study_modes?",
          :then: "study_mode_selection",
          :label: null
        },
        {
          :when: "multiple_schools?",
          :then: "school_selection",
          :label: null
        }
      ],
      :default: "study_mode_selection",
      :type: "multiple_conditional",
      :label: null
    }
  ],
  :counts: {
    :steps: 13,
    :simple_edges: 4,
    :conditional_edges: 2,
    :multiple_conditional_edges: 1,
    :custom_branching_edges: 0
  },
  :wizard_name: "Apply teacher training wizard"
}
```

**Note:** This is the unified metadata format consumed by all documentation formatters.
