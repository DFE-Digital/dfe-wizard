# Wizard Documentation

**Structure Type:** `graph`
**Generated:** 2025-12-22T07:03:20Z
**Processor:** DfE::Wizard::StepsProcessor


## Overview

| Metric                           | Value                       |
|----------------------------------|-----------------------------|
| Total Steps                      | 20              |
| Simple Transitions               | 0       |
| Conditional Transitions          | 0         |
| Multiple Conditional Transitions | 0        |
| Custom Branching Transitions     | 0       |
| **Total Transitions**            | **0**    |


## Root Entry Point (Fixed)

**Entry Point:** `find_ect`

All users start at this step. No conditional logic applies.


## Wizard Flow

```
[:find_ect]
├─→ [:trn_not_found] TRN not found
├─→ [:national_insurance_number] National Insurance number
│ ├─→ [:not_found] In TRS?
│ ├─→ [:induction_completed] Induction completed?
│ ├─→ [:induction_exempt] Induction exempt
│ └─→ [:review_ect_details] Review ECT details
│     ↓
│   [:email_address]
│   ├─→ [:cant_use_email]  (✓)
│   └─→ [:start_date]  (✗)
│       ↓
│     [:working_pattern]
│     ├─→ [:independent_school_appropriate_body]  (✓)
│     │   ↓
│     │ [:programme_type]
│     │ ├─→ [:lead_provider]  (✓)
│     │ │   ↓
│     │ │ [:check_answers]
│     │ │   ↓
│     │ │ [:confirmation]
│     │ └─→ [:check_answers]  (✗)
│     └─→ [:state_school_appropriate_body]  (✗)
│         ↓
│       [:programme_type]
├─→ [:already_active_at_school] Already active at school
├─→ [:induction_completed] Induction completed
├─→ [:induction_exempt] Induction exempt
├─→ [:cannot_register_ect] Can not register ECT
└─→ [:review_ect_details] Review ECT details
```

### Legend

- **━━** Simple edge (linear progression, no condition)
- **─┬─** Conditional edge (if/else decision point)
- **┼** Multiple conditional edge (N-way branching)
- **⊕** Custom branching edge (complex status-driven routing)


## Steps Inventory

| Step ID | Label | Class |
|---------|-------|-------|
| `cannot_register_ect` | Cannot Register Ect | `Steps::RegisterECT::CannotRegisterECTStep` |
| `cant_use_email` | Cant Use Email | `Steps::RegisterECT::CantUseEmailStep` |
| `check_answers` | Check Answers | `Steps::RegisterECT::CheckAnswersStep` |
| `confirmation` | Confirmation | `Steps::RegisterECT::ConfirmationStep` |
| `email_address` | Email Address | `Steps::RegisterECT::EmailAddressStep` |
| `find_ect` | Find Ect | `Steps::RegisterECT::FindECTStep` |
| `trn_not_found` | Trn Not Found | `Steps::RegisterECT::TRNNotFoundStep` |
| `already_active_at_school` | Already Active At School | `Steps::RegisterECT::AlreadyActiveAtSchoolStep` |
| `independent_school_appropriate_body` | Independent School Appropriate Body | `Steps::RegisterECT::IndependentSchoolAppropriateBodyStep` |
| `induction_completed` | Induction Completed | `Steps::RegisterECT::InductionCompletedStep` |
| `induction_exempt` | Induction Exempt | `Steps::RegisterECT::InductionExemptStep` |
| `induction_failed` | Induction Failed | `Steps::RegisterECT::InductionFailedStep` |
| `lead_provider` | Lead Provider | `Steps::RegisterECT::LeadProviderStep` |
| `national_insurance_number` | National Insurance Number | `Steps::RegisterECT::NationalInsuranceNumberStep` |
| `not_found` | Not Found | `Steps::RegisterECT::NotFoundStep` |
| `programme_type` | Programme Type | `Steps::RegisterECT::ProgrammeTypeStep` |
| `review_ect_details` | Review Ect Details | `Steps::RegisterECT::ReviewECTDetailsStep` |
| `start_date` | Start Date | `Steps::RegisterECT::StartDateStep` |
| `state_school_appropriate_body` | State School Appropriate Body | `Steps::RegisterECT::StateSchoolAppropriateBodyStep` |
| `working_pattern` | Working Pattern | `Steps::RegisterECT::WorkingPatternStep` |


## Detailed Step Specifications

### Step: `cannot_register_ect`

**Label:** Cannot Register Ect
**Class:** `Steps::RegisterECT::CannotRegisterECTStep`
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


### Step: `cant_use_email`

**Label:** Cant Use Email
**Class:** `Steps::RegisterECT::CantUseEmailStep`
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


### Step: `check_answers`

**Label:** Check Answers
**Class:** `Steps::RegisterECT::CheckAnswersStep`
**Entry Point:** ✗ No
**Exit Points:** `confirmation`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `confirmation`

**Label:** Confirmation
**Class:** `Steps::RegisterECT::ConfirmationStep`
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


### Step: `email_address`

**Label:** Email Address
**Class:** `Steps::RegisterECT::EmailAddressStep`
**Entry Point:** ✗ No
**Exit Points:** `cant_use_email`, `start_date`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `email` | `ActiveModel::Type::String` | ✗ |  |

#### Validations

- **email** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `find_ect`

**Label:** Find Ect
**Class:** `Steps::RegisterECT::FindECTStep`
**Entry Point:** ✓ Yes
**Exit Points:** `already_active_at_school`, `cannot_register_ect`, `induction_completed`, `induction_exempt`, `national_insurance_number`, `review_ect_details`, `trn_not_found`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `trn` | `ActiveModel::Type::String` | ✗ |  |
| `date_of_birth` | `ActiveModel::Type::Date` | ✗ |  |

#### Validations

- **trn** (`presence`): 
- **date_of_birth** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `trn_not_found`

**Label:** Trn Not Found
**Class:** `Steps::RegisterECT::TRNNotFoundStep`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `national_insurance_number` | `ActiveModel::Type::String` | ✗ |  |

#### Validations

- **national_insurance_number** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `already_active_at_school`

**Label:** Already Active At School
**Class:** `Steps::RegisterECT::AlreadyActiveAtSchoolStep`
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


### Step: `independent_school_appropriate_body`

**Label:** Independent School Appropriate Body
**Class:** `Steps::RegisterECT::IndependentSchoolAppropriateBodyStep`
**Entry Point:** ✗ No
**Exit Points:** `programme_type`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `induction_completed`

**Label:** Induction Completed
**Class:** `Steps::RegisterECT::InductionCompletedStep`
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


### Step: `induction_exempt`

**Label:** Induction Exempt
**Class:** `Steps::RegisterECT::InductionExemptStep`
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


### Step: `induction_failed`

**Label:** Induction Failed
**Class:** `Steps::RegisterECT::InductionFailedStep`
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


### Step: `lead_provider`

**Label:** Lead Provider
**Class:** `Steps::RegisterECT::LeadProviderStep`
**Entry Point:** ✗ No
**Exit Points:** `check_answers`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `national_insurance_number`

**Label:** National Insurance Number
**Class:** `Steps::RegisterECT::NationalInsuranceNumberStep`
**Entry Point:** ✗ No
**Exit Points:** `induction_completed`, `induction_exempt`, `not_found`, `review_ect_details`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `not_found`

**Label:** Not Found
**Class:** `Steps::RegisterECT::NotFoundStep`
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


### Step: `programme_type`

**Label:** Programme Type
**Class:** `Steps::RegisterECT::ProgrammeTypeStep`
**Entry Point:** ✗ No
**Exit Points:** `check_answers`, `lead_provider`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `review_ect_details`

**Label:** Review Ect Details
**Class:** `Steps::RegisterECT::ReviewECTDetailsStep`
**Entry Point:** ✗ No
**Exit Points:** `email_address`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `details_correct` | `ActiveModel::Type::String` | ✗ |  |
| `correct_full_name` | `ActiveModel::Type::String` | ✗ |  |

#### Validations

- **details_correct** (`presence`): 
- **correct_full_name** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `start_date`

**Label:** Start Date
**Class:** `Steps::RegisterECT::StartDateStep`
**Entry Point:** ✗ No
**Exit Points:** `working_pattern`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `state_school_appropriate_body`

**Label:** State School Appropriate Body
**Class:** `Steps::RegisterECT::StateSchoolAppropriateBodyStep`
**Entry Point:** ✗ No
**Exit Points:** `programme_type`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `appropriate_body_name` | `ActiveModel::Type::String` | ✗ |  |

#### Validations

- **appropriate_body_name** (`presence`): Enter the name of the appropriate body which will be supporting the ECT's induction

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `working_pattern`

**Label:** Working Pattern
**Class:** `Steps::RegisterECT::WorkingPatternStep`
**Entry Point:** ✗ No
**Exit Points:** `independent_school_appropriate_body`, `state_school_appropriate_body`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


## Transitions Reference

This wizard contains **11 transitions** across 4 types:

- **6 simple transitions** – Linear progression (unconditional)
- **3 conditional transitions** – If/else branching logic
- **0 multiple conditional transitions** – N-way branching
- **2 custom branching transitions** – Complex status-driven routing


### Simple Transitions

Simple transitions allow linear, unconditional progression from one step to the next.

| From | To | Behavior |
|------|-----|----------|
| `review_ect_details` | `email_address` | Always proceeds (no condition) |
| `start_date` | `working_pattern` | Always proceeds (no condition) |
| `independent_school_appropriate_body` | `programme_type` | Always proceeds (no condition) |
| `state_school_appropriate_body` | `programme_type` | Always proceeds (no condition) |
| `lead_provider` | `check_answers` | Always proceeds (no condition) |
| `check_answers` | `confirmation` | Always proceeds (no condition) |


### Conditional Transitions (If/Else)


Conditional transitions split the flow into two branches based on a predicate evaluation.


#### `email_address` → `cant_use_email` OR `start_date`

| Property | Value |
|----------|-------|
| From | `email_address` |
| Condition | `Condition` |
| Then (if true) | `cant_use_email` |
| Else (if false) | `start_date` |

**Flow Logic:**

Evaluates the predicate `Condition`:
- If condition is **true** → proceed to `cant_use_email`
- If condition is **false** → proceed to `start_date`


#### `working_pattern` → `independent_school_appropriate_body` OR `state_school_appropriate_body`

| Property | Value |
|----------|-------|
| From | `working_pattern` |
| Condition | `Condition` |
| Then (if true) | `independent_school_appropriate_body` |
| Else (if false) | `state_school_appropriate_body` |

**Flow Logic:**

Evaluates the predicate `Condition`:
- If condition is **true** → proceed to `independent_school_appropriate_body`
- If condition is **false** → proceed to `state_school_appropriate_body`


#### `programme_type` → `lead_provider` OR `check_answers`

| Property | Value |
|----------|-------|
| From | `programme_type` |
| Condition | `Condition` |
| Then (if true) | `lead_provider` |
| Else (if false) | `check_answers` |

**Flow Logic:**

Evaluates the predicate `Condition`:
- If condition is **true** → proceed to `lead_provider`
- If condition is **false** → proceed to `check_answers`
"


### Custom Branching Transitions (Status-Driven)

Custom branching uses a method to evaluate complex logic and route to multiple possible destinations.

#### `find_ect` → Multiple Destinations (Custom Logic)

| Property | Value |
|----------|-------|
| From | `find_ect` |
| Type | Custom Branching |

**Potential Transitions:**

| Condition | Destination(s) |
|-----------|-----------------|
| TRN not found | `trn_not_found` |
| National Insurance number | `national_insurance_number` |
| Already active at school | `already_active_at_school` |
| Induction completed | `induction_completed` |
| Induction exempt | `induction_exempt` |
| Can not register ECT | `cannot_register_ect` |
| Review ECT details | `review_ect_details` |


#### `national_insurance_number` → Multiple Destinations (Custom Logic)

| Property | Value |
|----------|-------|
| From | `national_insurance_number` |
| Type | Custom Branching |

**Potential Transitions:**

| Condition | Destination(s) |
|-----------|-----------------|
| In TRS? | `not_found` |
| Induction completed? | `induction_completed` |
| Induction exempt | `induction_exempt` |
| Review ECT details | `review_ect_details` |



## Wizard Statistics

| Metric | Count |
|--------|-------|
| Total Steps | 20 |
| Simple Transitions | 0 |
| Conditional Transitions | 0 |
| Multiple Conditional Transitions | 0 |
| Custom Branching Transitions | 0 |
| **Total Transitions** | **11** |


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
  :root_step: "find_ect",
  :steps: {
    :cannot_register_ect: {
      :class: "Steps::RegisterECT::CannotRegisterECTStep",
      :label: "Cannot Register Ect",
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
    :cant_use_email: {
      :class: "Steps::RegisterECT::CantUseEmailStep",
      :label: "Cant Use Email",
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
    :check_answers: {
      :class: "Steps::RegisterECT::CheckAnswersStep",
      :label: "Check Answers",
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
    :confirmation: {
      :class: "Steps::RegisterECT::ConfirmationStep",
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
    },
    :email_address: {
      :class: "Steps::RegisterECT::EmailAddressStep",
      :label: "Email Address",
      :attributes: [
        {
          :name: "email",
          :type: "ActiveModel::Type::String"
        }
      ],
      :validators: [
        {
          :name: "email",
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
    :find_ect: {
      :class: "Steps::RegisterECT::FindECTStep",
      :label: "Find Ect",
      :attributes: [
        {
          :name: "trn",
          :type: "ActiveModel::Type::String"
        },
        {
          :name: "date_of_birth",
          :type: "ActiveModel::Type::Date"
        }
      ],
      :validators: [
        {
          :name: "trn",
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
    :trn_not_found: {
      :class: "Steps::RegisterECT::TRNNotFoundStep",
      :label: "Trn Not Found",
      :attributes: [
        {
          :name: "national_insurance_number",
          :type: "ActiveModel::Type::String"
        }
      ],
      :validators: [
        {
          :name: "national_insurance_number",
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
    :already_active_at_school: {
      :class: "Steps::RegisterECT::AlreadyActiveAtSchoolStep",
      :label: "Already Active At School",
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
    :independent_school_appropriate_body: {
      :class: "Steps::RegisterECT::IndependentSchoolAppropriateBodyStep",
      :label: "Independent School Appropriate Body",
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
    :induction_completed: {
      :class: "Steps::RegisterECT::InductionCompletedStep",
      :label: "Induction Completed",
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
    :induction_exempt: {
      :class: "Steps::RegisterECT::InductionExemptStep",
      :label: "Induction Exempt",
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
    :induction_failed: {
      :class: "Steps::RegisterECT::InductionFailedStep",
      :label: "Induction Failed",
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
    :lead_provider: {
      :class: "Steps::RegisterECT::LeadProviderStep",
      :label: "Lead Provider",
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
    :national_insurance_number: {
      :class: "Steps::RegisterECT::NationalInsuranceNumberStep",
      :label: "National Insurance Number",
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
    :not_found: {
      :class: "Steps::RegisterECT::NotFoundStep",
      :label: "Not Found",
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
    :programme_type: {
      :class: "Steps::RegisterECT::ProgrammeTypeStep",
      :label: "Programme Type",
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
    :review_ect_details: {
      :class: "Steps::RegisterECT::ReviewECTDetailsStep",
      :label: "Review Ect Details",
      :attributes: [
        {
          :name: "details_correct",
          :type: "ActiveModel::Type::String"
        },
        {
          :name: "correct_full_name",
          :type: "ActiveModel::Type::String"
        }
      ],
      :validators: [
        {
          :name: "details_correct",
          :class: "ActiveModel::Validations::PresenceValidator",
          :type: "presence",
          :message: null
        },
        {
          :name: "correct_full_name",
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
    :start_date: {
      :class: "Steps::RegisterECT::StartDateStep",
      :label: "Start Date",
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
    :state_school_appropriate_body: {
      :class: "Steps::RegisterECT::StateSchoolAppropriateBodyStep",
      :label: "State School Appropriate Body",
      :attributes: [
        {
          :name: "appropriate_body_name",
          :type: "ActiveModel::Type::String"
        }
      ],
      :validators: [
        {
          :name: "appropriate_body_name",
          :class: "ActiveModel::Validations::PresenceValidator",
          :type: "presence",
          :message: "Enter the name of the appropriate body which will be supporting the ECT's induction"
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
    :working_pattern: {
      :class: "Steps::RegisterECT::WorkingPatternStep",
      :label: "Working Pattern",
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
      :from: "review_ect_details",
      :to: "email_address",
      :type: "simple",
      :label: null
    },
    {
      :from: "start_date",
      :to: "working_pattern",
      :type: "simple",
      :label: null
    },
    {
      :from: "independent_school_appropriate_body",
      :to: "programme_type",
      :type: "simple",
      :label: null
    },
    {
      :from: "state_school_appropriate_body",
      :to: "programme_type",
      :type: "simple",
      :label: null
    },
    {
      :from: "lead_provider",
      :to: "check_answers",
      :type: "simple",
      :label: null
    },
    {
      :from: "check_answers",
      :to: "confirmation",
      :type: "simple",
      :label: null
    },
    {
      :from: "email_address",
      :when: "cant_use_email?",
      :then: "cant_use_email",
      :else: "start_date",
      :type: "conditional",
      :label: null
    },
    {
      :from: "working_pattern",
      :when: "school_independent?",
      :then: "independent_school_appropriate_body",
      :else: "state_school_appropriate_body",
      :type: "conditional",
      :label: null
    },
    {
      :from: "programme_type",
      :when: "provider_led?",
      :then: "lead_provider",
      :else: "check_answers",
      :type: "conditional",
      :label: null
    },
    {
      :from: "find_ect",
      :type: "custom_branching",
      :potential_transitions: [
        {
          :label: "TRN not found",
          :nodes: [
            "trn_not_found"
          ]
        },
        {
          :label: "National Insurance number",
          :nodes: [
            "national_insurance_number"
          ]
        },
        {
          :label: "Already active at school",
          :nodes: [
            "already_active_at_school"
          ]
        },
        {
          :label: "Induction completed",
          :nodes: [
            "induction_completed"
          ]
        },
        {
          :label: "Induction exempt",
          :nodes: [
            "induction_exempt"
          ]
        },
        {
          :label: "Can not register ECT",
          :nodes: [
            "cannot_register_ect"
          ]
        },
        {
          :label: "Review ECT details",
          :nodes: [
            "review_ect_details"
          ]
        }
      ]
    },
    {
      :from: "national_insurance_number",
      :type: "custom_branching",
      :potential_transitions: [
        {
          :label: "In TRS?",
          :nodes: [
            "not_found"
          ]
        },
        {
          :label: "Induction completed?",
          :nodes: [
            "induction_completed"
          ]
        },
        {
          :label: "Induction exempt",
          :nodes: [
            "induction_exempt"
          ]
        },
        {
          :label: "Review ECT details",
          :nodes: [
            "review_ect_details"
          ]
        }
      ]
    }
  ],
  :counts: {
    :steps: 20,
    :simple_edges: 6,
    :conditional_edges: 3,
    :multiple_conditional_edges: 0,
    :custom_branching_edges: 2
  },
  :wizard_name: "Register ECT wizard"
}
```

**Note:** This is the unified metadata format consumed by all documentation formatters.
