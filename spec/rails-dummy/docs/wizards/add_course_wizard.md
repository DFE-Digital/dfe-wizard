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

**Entry Point:** `level`

All users start at this step. No conditional logic applies.


## Wizard Flow

```
[:level]
  ↓
[:outcome]
├─→ [:school]  (✓)
│   ↓
│ [:study_site]
│ ├─→ [:applications_open]  (✓)
│ │   ↓
│ │ [:start_date]
│ │   ↓
│ │ [:review]
│ │   ↓
│ │ [:courses_list]
│ └─→ [:accredited_provider]  (✗)
│   ├─→ [:applications_open]
│   └─→ [:can_sponsor_student_visa]
│     ├─→ [:visa_sponsorship_application_deadline_required]  (✓)
│     │ ├─→ [:visa_sponsorship_application_deadline_at]  (✓)
│     │ │   ↓
│     │ │ [:applications_open]
│     │ └─→ [:applications_open]  (✗)
│     └─→ [:applications_open]  (✗)
└─→ [:funding_type]  (✗)
    ↓
  [:full_or_part_time]
    ↓
  [:school]
```

### Legend

- **━━** Simple edge (linear progression, no condition)
- **─┬─** Conditional edge (if/else decision point)
- **┼** Multiple conditional edge (N-way branching)
- **⊕** Custom branching edge (complex status-driven routing)


## Steps Inventory

| Step ID | Label | Class |
|---------|-------|-------|
| `level` | Level | `Steps::Courses::Level` |
| `subjects` | Subjects | `Steps::Courses::Subjects` |
| `design_technology` | Design Technology | `Steps::Courses::DesignTechnology` |
| `modern_languages` | Modern Languages | `Steps::Courses::ModernLanguages` |
| `engineers_teach_physics` | Engineers Teach Physics | `Steps::Courses::EngineersTeachPhysics` |
| `age_range` | Age Range | `Steps::Courses::AgeRange` |
| `outcome` | Outcome | `Steps::Courses::Outcome` |
| `funding_type` | Funding Type | `Steps::Courses::FundingType` |
| `full_or_part_time` | Full Or Part Time | `Steps::Courses::FullOrPartTime` |
| `school` | School | `Steps::Courses::School` |
| `study_site` | Study Site | `Steps::Courses::StudySite` |
| `accredited_provider` | Accredited Provider | `Steps::Courses::AccreditedProvider` |
| `can_sponsor_student_visa` | Can Sponsor Student Visa | `Steps::Courses::CanSponsorStudentVisa` |
| `can_sponsor_skilled_worker_visa` | Can Sponsor Skilled Worker Visa | `Steps::Courses::CanSponsorSkilledWorkerVisa` |
| `visa_sponsorship_application_deadline_required` | Visa Sponsorship Application Deadline Required | `Steps::Courses::VisaSponsorshipDeadlineRequired` |
| `visa_sponsorship_application_deadline_at` | Visa Sponsorship Application Deadline At | `Steps::Courses::VisaSponsorshipDeadlineAt` |
| `applications_open` | Applications Open | `Steps::Courses::ApplicationsOpen` |
| `start_date` | Start Date | `Steps::Courses::StartDate` |
| `review` | Review | `Steps::Courses::Review` |
| `courses_list` | Courses List | `DfE::Wizard::Core::Redirect` |


## Detailed Step Specifications

### Step: `level`

**Label:** Level
**Class:** `Steps::Courses::Level`
**Entry Point:** ✓ Yes
**Exit Points:** `outcome`, `subjects`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `level` | `ActiveModel::Type::String` | ✗ |  |
| `send` | `ActiveModel::Type::String` | ✗ |  |

#### Validations

- **level** (`presence`): 
- **send** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `subjects`

**Label:** Subjects
**Class:** `Steps::Courses::Subjects`
**Entry Point:** ✗ No
**Exit Points:** `age_range`, `design_technology`, `engineers_teach_physics`, `modern_languages`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `main_subject` | `ActiveModel::Type::String` | ✗ |  |
| `second_subject` | `ActiveModel::Type::String` | ✗ |  |

#### Validations

- **main_subject** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `design_technology`

**Label:** Design Technology
**Class:** `Steps::Courses::DesignTechnology`
**Entry Point:** ✗ No
**Exit Points:** `age_range`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `modern_languages`

**Label:** Modern Languages
**Class:** `Steps::Courses::ModernLanguages`
**Entry Point:** ✗ No
**Exit Points:** `age_range`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `engineers_teach_physics`

**Label:** Engineers Teach Physics
**Class:** `Steps::Courses::EngineersTeachPhysics`
**Entry Point:** ✗ No
**Exit Points:** `age_range`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `age_range`

**Label:** Age Range
**Class:** `Steps::Courses::AgeRange`
**Entry Point:** ✗ No
**Exit Points:** `outcome`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `outcome`

**Label:** Outcome
**Class:** `Steps::Courses::Outcome`
**Entry Point:** ✗ No
**Exit Points:** `funding_type`, `school`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `qualification` | `ActiveModel::Type::String` | ✗ |  |

#### Validations

- **qualification** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `funding_type`

**Label:** Funding Type
**Class:** `Steps::Courses::FundingType`
**Entry Point:** ✗ No
**Exit Points:** `full_or_part_time`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `funding_type` | `ActiveModel::Type::String` | ✗ |  |

#### Validations

- **funding_type** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `full_or_part_time`

**Label:** Full Or Part Time
**Class:** `Steps::Courses::FullOrPartTime`
**Entry Point:** ✗ No
**Exit Points:** `school`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `school`

**Label:** School
**Class:** `Steps::Courses::School`
**Entry Point:** ✗ No
**Exit Points:** `study_site`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `study_site`

**Label:** Study Site
**Class:** `Steps::Courses::StudySite`
**Entry Point:** ✗ No
**Exit Points:** `accredited_provider`, `applications_open`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `accredited_provider`

**Label:** Accredited Provider
**Class:** `Steps::Courses::AccreditedProvider`
**Entry Point:** ✗ No
**Exit Points:** `applications_open`, `can_sponsor_skilled_worker_visa`, `can_sponsor_student_visa`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `can_sponsor_student_visa`

**Label:** Can Sponsor Student Visa
**Class:** `Steps::Courses::CanSponsorStudentVisa`
**Entry Point:** ✗ No
**Exit Points:** `applications_open`, `visa_sponsorship_application_deadline_required`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `can_sponsor_student_visa` | `ActiveModel::Type::Boolean` | ✗ |  |

#### Validations

- **can_sponsor_student_visa** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `can_sponsor_skilled_worker_visa`

**Label:** Can Sponsor Skilled Worker Visa
**Class:** `Steps::Courses::CanSponsorSkilledWorkerVisa`
**Entry Point:** ✗ No
**Exit Points:** `applications_open`, `visa_sponsorship_application_deadline_required`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `can_sponsor_skilled_worker_visa` | `ActiveModel::Type::Boolean` | ✗ |  |

#### Validations

- **can_sponsor_skilled_worker_visa** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `visa_sponsorship_application_deadline_required`

**Label:** Visa Sponsorship Application Deadline Required
**Class:** `Steps::Courses::VisaSponsorshipDeadlineRequired`
**Entry Point:** ✗ No
**Exit Points:** `applications_open`, `visa_sponsorship_application_deadline_at`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `visa_deadline_required` | `ActiveModel::Type::Boolean` | ✗ |  |

#### Validations

- **visa_deadline_required** (`presence`): 

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `visa_sponsorship_application_deadline_at`

**Label:** Visa Sponsorship Application Deadline At
**Class:** `Steps::Courses::VisaSponsorshipDeadlineAt`
**Entry Point:** ✗ No
**Exit Points:** `applications_open`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `applications_open`

**Label:** Applications Open
**Class:** `Steps::Courses::ApplicationsOpen`
**Entry Point:** ✗ No
**Exit Points:** `start_date`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `start_date`

**Label:** Start Date
**Class:** `Steps::Courses::StartDate`
**Entry Point:** ✗ No
**Exit Points:** `review`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `review`

**Label:** Review
**Class:** `Steps::Courses::Review`
**Entry Point:** ✗ No
**Exit Points:** `courses_list`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate` | Validate operation |
| `persist` | Persist operation |


### Step: `courses_list`

**Label:** Courses List
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

This wizard contains **19 transitions** across 4 types:

- **11 simple transitions** – Linear progression (unconditional)
- **5 conditional transitions** – If/else branching logic
- **3 multiple conditional transitions** – N-way branching
- **0 custom branching transitions** – Complex status-driven routing


### Simple Transitions

Simple transitions allow linear, unconditional progression from one step to the next.

| From | To | Behavior |
|------|-----|----------|
| `funding_type` | `full_or_part_time` | Always proceeds (no condition) |
| `full_or_part_time` | `school` | Always proceeds (no condition) |
| `school` | `study_site` | Always proceeds (no condition) |
| `design_technology` | `age_range` | Always proceeds (no condition) |
| `modern_languages` | `age_range` | Always proceeds (no condition) |
| `engineers_teach_physics` | `age_range` | Always proceeds (no condition) |
| `age_range` | `outcome` | Always proceeds (no condition) |
| `visa_sponsorship_application_deadline_at` | `applications_open` | Always proceeds (no condition) |
| `applications_open` | `start_date` | Always proceeds (no condition) |
| `start_date` | `review` | Always proceeds (no condition) |
| `review` | `courses_list` | Always proceeds (no condition) |


### Conditional Transitions (If/Else)


Conditional transitions split the flow into two branches based on a predicate evaluation.


#### `outcome` → `school` OR `funding_type`

| Property | Value |
|----------|-------|
| From | `outcome` |
| Condition | `Condition` |
| Then (if true) | `school` |
| Else (if false) | `funding_type` |

**Flow Logic:**

Evaluates the predicate `Condition`:
- If condition is **true** → proceed to `school`
- If condition is **false** → proceed to `funding_type`


#### `study_site` → `applications_open` OR `accredited_provider`

| Property | Value |
|----------|-------|
| From | `study_site` |
| Condition | `Condition` |
| Then (if true) | `applications_open` |
| Else (if false) | `accredited_provider` |

**Flow Logic:**

Evaluates the predicate `Condition`:
- If condition is **true** → proceed to `applications_open`
- If condition is **false** → proceed to `accredited_provider`


#### `can_sponsor_student_visa` → `visa_sponsorship_application_deadline_required` OR `applications_open`

| Property | Value |
|----------|-------|
| From | `can_sponsor_student_visa` |
| Condition | `Condition` |
| Then (if true) | `visa_sponsorship_application_deadline_required` |
| Else (if false) | `applications_open` |

**Flow Logic:**

Evaluates the predicate `Condition`:
- If condition is **true** → proceed to `visa_sponsorship_application_deadline_required`
- If condition is **false** → proceed to `applications_open`


#### `can_sponsor_skilled_worker_visa` → `visa_sponsorship_application_deadline_required` OR `applications_open`

| Property | Value |
|----------|-------|
| From | `can_sponsor_skilled_worker_visa` |
| Condition | `Condition` |
| Then (if true) | `visa_sponsorship_application_deadline_required` |
| Else (if false) | `applications_open` |

**Flow Logic:**

Evaluates the predicate `Condition`:
- If condition is **true** → proceed to `visa_sponsorship_application_deadline_required`
- If condition is **false** → proceed to `applications_open`


#### `visa_sponsorship_application_deadline_required` → `visa_sponsorship_application_deadline_at` OR `applications_open`

| Property | Value |
|----------|-------|
| From | `visa_sponsorship_application_deadline_required` |
| Condition | `Condition` |
| Then (if true) | `visa_sponsorship_application_deadline_at` |
| Else (if false) | `applications_open` |

**Flow Logic:**

Evaluates the predicate `Condition`:
- If condition is **true** → proceed to `visa_sponsorship_application_deadline_at`
- If condition is **false** → proceed to `applications_open`
"


### Multiple Conditional Transitions (N-way Branching)


N-way transitions route to different steps based on multiple independent conditions.


#### `level` → Multiple Destinations (1 branches)

| Property | Value |
|----------|-------|
| From | `level` |
| Label | Classification |
| Type | Multiple Conditional (N-way) |
| Default | `subjects` |

**Branches:**

| Branch | Destination |
|--------|-------------|
|  | `outcome` |
| (default, no match) | `subjects` |


#### `subjects` → Multiple Destinations (3 branches)

| Property | Value |
|----------|-------|
| From | `subjects` |
| Label | Classification |
| Type | Multiple Conditional (N-way) |
| Default | `age_range` |

**Branches:**

| Branch | Destination |
|--------|-------------|
|  | `design_technology` |
|  | `modern_languages` |
|  | `engineers_teach_physics` |
| (default, no match) | `age_range` |


#### `accredited_provider` → Multiple Destinations (2 branches)

| Property | Value |
|----------|-------|
| From | `accredited_provider` |
| Label | Classification |
| Type | Multiple Conditional (N-way) |
| Default | `can_sponsor_skilled_worker_visa` |

**Branches:**

| Branch | Destination |
|--------|-------------|
|  | `applications_open` |
|  | `can_sponsor_student_visa` |
| (default, no match) | `can_sponsor_skilled_worker_visa` |
"


## Wizard Statistics

| Metric | Count |
|--------|-------|
| Total Steps | 20 |
| Simple Transitions | 0 |
| Conditional Transitions | 0 |
| Multiple Conditional Transitions | 0 |
| Custom Branching Transitions | 0 |
| **Total Transitions** | **19** |


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
  :root_step: "level",
  :steps: {
    :level: {
      :class: "Steps::Courses::Level",
      :label: "Level",
      :attributes: [
        {
          :name: "level",
          :type: "ActiveModel::Type::String"
        },
        {
          :name: "send",
          :type: "ActiveModel::Type::String"
        }
      ],
      :validators: [
        {
          :name: "level",
          :class: "ActiveModel::Validations::PresenceValidator",
          :type: "presence",
          :message: null
        },
        {
          :name: "send",
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
    :subjects: {
      :class: "Steps::Courses::Subjects",
      :label: "Subjects",
      :attributes: [
        {
          :name: "main_subject",
          :type: "ActiveModel::Type::String"
        },
        {
          :name: "second_subject",
          :type: "ActiveModel::Type::String"
        }
      ],
      :validators: [
        {
          :name: "main_subject",
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
    :design_technology: {
      :class: "Steps::Courses::DesignTechnology",
      :label: "Design Technology",
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
    :modern_languages: {
      :class: "Steps::Courses::ModernLanguages",
      :label: "Modern Languages",
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
    :engineers_teach_physics: {
      :class: "Steps::Courses::EngineersTeachPhysics",
      :label: "Engineers Teach Physics",
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
    :age_range: {
      :class: "Steps::Courses::AgeRange",
      :label: "Age Range",
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
    :outcome: {
      :class: "Steps::Courses::Outcome",
      :label: "Outcome",
      :attributes: [
        {
          :name: "qualification",
          :type: "ActiveModel::Type::String"
        }
      ],
      :validators: [
        {
          :name: "qualification",
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
    :funding_type: {
      :class: "Steps::Courses::FundingType",
      :label: "Funding Type",
      :attributes: [
        {
          :name: "funding_type",
          :type: "ActiveModel::Type::String"
        }
      ],
      :validators: [
        {
          :name: "funding_type",
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
    :full_or_part_time: {
      :class: "Steps::Courses::FullOrPartTime",
      :label: "Full Or Part Time",
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
    :school: {
      :class: "Steps::Courses::School",
      :label: "School",
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
    :study_site: {
      :class: "Steps::Courses::StudySite",
      :label: "Study Site",
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
    :accredited_provider: {
      :class: "Steps::Courses::AccreditedProvider",
      :label: "Accredited Provider",
      :skippable?: true,
      :skip_when: "single_accredited_provider_or_self_accredited?",
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
    :can_sponsor_student_visa: {
      :class: "Steps::Courses::CanSponsorStudentVisa",
      :label: "Can Sponsor Student Visa",
      :attributes: [
        {
          :name: "can_sponsor_student_visa",
          :type: "ActiveModel::Type::Boolean"
        }
      ],
      :validators: [
        {
          :name: "can_sponsor_student_visa",
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
    :can_sponsor_skilled_worker_visa: {
      :class: "Steps::Courses::CanSponsorSkilledWorkerVisa",
      :label: "Can Sponsor Skilled Worker Visa",
      :attributes: [
        {
          :name: "can_sponsor_skilled_worker_visa",
          :type: "ActiveModel::Type::Boolean"
        }
      ],
      :validators: [
        {
          :name: "can_sponsor_skilled_worker_visa",
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
    :visa_sponsorship_application_deadline_required: {
      :class: "Steps::Courses::VisaSponsorshipDeadlineRequired",
      :label: "Visa Sponsorship Application Deadline Required",
      :attributes: [
        {
          :name: "visa_deadline_required",
          :type: "ActiveModel::Type::Boolean"
        }
      ],
      :validators: [
        {
          :name: "visa_deadline_required",
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
    :visa_sponsorship_application_deadline_at: {
      :class: "Steps::Courses::VisaSponsorshipDeadlineAt",
      :label: "Visa Sponsorship Application Deadline At",
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
    :applications_open: {
      :class: "Steps::Courses::ApplicationsOpen",
      :label: "Applications Open",
      :skippable?: true,
      :skip_when: "applications_open_feature_flag_inactive?",
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
    :start_date: {
      :class: "Steps::Courses::StartDate",
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
    :review: {
      :class: "Steps::Courses::Review",
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
    :courses_list: {
      :class: "DfE::Wizard::Core::Redirect",
      :label: "Courses List",
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
      :from: "funding_type",
      :to: "full_or_part_time",
      :type: "simple",
      :label: null
    },
    {
      :from: "full_or_part_time",
      :to: "school",
      :type: "simple",
      :label: null
    },
    {
      :from: "school",
      :to: "study_site",
      :type: "simple",
      :label: null
    },
    {
      :from: "design_technology",
      :to: "age_range",
      :type: "simple",
      :label: null
    },
    {
      :from: "modern_languages",
      :to: "age_range",
      :type: "simple",
      :label: null
    },
    {
      :from: "engineers_teach_physics",
      :to: "age_range",
      :type: "simple",
      :label: null
    },
    {
      :from: "age_range",
      :to: "outcome",
      :type: "simple",
      :label: null
    },
    {
      :from: "visa_sponsorship_application_deadline_at",
      :to: "applications_open",
      :type: "simple",
      :label: null
    },
    {
      :from: "applications_open",
      :to: "start_date",
      :type: "simple",
      :label: null
    },
    {
      :from: "start_date",
      :to: "review",
      :type: "simple",
      :label: null
    },
    {
      :from: "review",
      :to: "courses_list",
      :type: "simple",
      :label: null
    },
    {
      :from: "outcome",
      :when: "teacher_degree_apprenticeship?",
      :then: "school",
      :else: "funding_type",
      :type: "conditional",
      :label: null
    },
    {
      :from: "study_site",
      :when: "further_education?",
      :then: "applications_open",
      :else: "accredited_provider",
      :type: "conditional",
      :label: null
    },
    {
      :from: "can_sponsor_student_visa",
      :when: "can_sponsor_student_visa?",
      :then: "visa_sponsorship_application_deadline_required",
      :else: "applications_open",
      :type: "conditional",
      :label: null
    },
    {
      :from: "can_sponsor_skilled_worker_visa",
      :when: "can_sponsor_skilled_worker_visa?",
      :then: "visa_sponsorship_application_deadline_required",
      :else: "applications_open",
      :type: "conditional",
      :label: null
    },
    {
      :from: "visa_sponsorship_application_deadline_required",
      :when: "visa_deadline_required?",
      :then: "visa_sponsorship_application_deadline_at",
      :else: "applications_open",
      :type: "conditional",
      :label: null
    },
    {
      :from: "level",
      :branches: [
        {
          :when: "further_education?",
          :then: "outcome",
          :label: null
        }
      ],
      :default: "subjects",
      :type: "multiple_conditional",
      :label: null
    },
    {
      :from: "subjects",
      :branches: [
        {
          :when: "design_technology?",
          :then: "design_technology",
          :label: null
        },
        {
          :when: "modern_languages?",
          :then: "modern_languages",
          :label: null
        },
        {
          :when: "physics?",
          :then: "engineers_teach_physics",
          :label: null
        }
      ],
      :default: "age_range",
      :type: "multiple_conditional",
      :label: null
    },
    {
      :from: "accredited_provider",
      :branches: [
        {
          :when: "teacher_degree_apprenticeship?",
          :then: "applications_open",
          :label: null
        },
        {
          :when: "fee_based?",
          :then: "can_sponsor_student_visa",
          :label: null
        }
      ],
      :default: "can_sponsor_skilled_worker_visa",
      :type: "multiple_conditional",
      :label: null
    }
  ],
  :counts: {
    :steps: 20,
    :simple_edges: 11,
    :conditional_edges: 5,
    :multiple_conditional_edges: 3,
    :custom_branching_edges: 0
  },
  :wizard_name: "Add course wizard"
}
```

**Note:** This is the unified metadata format consumed by all documentation formatters.
