# Wizard Documentation

**Structure Type:** `graph`
**Generated:** 2025-12-02T15:45:00Z
**Processor:** DfE::Wizard::StepsProcessor

## Overview

| Metric | Value |
|--------|-------|
| Total Steps | 2 |
| Simple Transitions | 1 |
| Conditional Transitions | 0 |
| Multiple Conditional Transitions | 0 |
| Custom Branching Transitions | 0 |
| **Total Transitions** | **1** |

## Root Entry Point (Fixed)

**Entry Point:** `personal_info`

All users start at this step. No conditional logic applies.

## Wizard Flow

```
[:personal_info]
  ↓
[:review]
```

### Legend

- **━━** Simple edge (linear progression, no condition)
- **─┬─** Conditional edge (if/else decision point)
- **┼** Multiple conditional edge (N-way branching)
- **⊕** Custom branching edge (complex status-driven routing)

## Steps Inventory

| Step ID | Label | Class |
|---------|-------|-------|
| `personal_info` | Personal Information | `Steps::PersonalInfo` |
| `review` | Review | `Steps::Review` |

## Detailed Step Specifications

### Step: `personal_info`

**Label:** Personal Information
**Class:** `Steps::PersonalInfo`
**Entry Point:** ✓ Yes
**Exit Points:** `review`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `first_name` | `String` | ✓ | First name of applicant |
| `last_name` | `String` | ✓ | Last name of applicant |
| `date_of_birth` | `Date` | ✓ | Date of birth (YYYY-MM-DD) |
| `email` | `String` | ✓ | Valid email address |

#### Validations

- **first_name** (`presence`): cannot be blank
- **email** (`format`): must be valid email
- **date_of_birth** (`comparison`): must be in past

#### Operations

| Operation | Description |
|-----------|-------------|
| `strip_whitespace` | Remove leading/trailing spaces |
| `send_confirmation_email` | Send email confirmation |

### Step: `review`

**Label:** Review
**Class:** `Steps::Review`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

## Transitions Reference

This wizard contains **1 transitions** across 4 types:

- **1 simple transitions** – Linear progression (unconditional)
- **0 conditional transitions** – If/else branching logic
- **0 multiple conditional transitions** – N-way branching
- **0 custom branching transitions** – Complex status-driven routing

### Simple Transitions

Simple transitions allow linear, unconditional progression from one step to the next.

| From | To | Behavior |
|------|-----|----------|
| `personal_info` | `review` | Always proceeds (no condition) |

## Wizard Statistics

| Metric | Count |
|--------|-------|
| Total Steps | 2 |
| Simple Transitions | 1 |
| Conditional Transitions | 0 |
| Multiple Conditional Transitions | 0 |
| Custom Branching Transitions | 0 |
| **Total Transitions** | **1** |

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
  "structure_type": "graph",
  "root_step": "personal_info",
  "steps": {
    "personal_info": {
      "label": "Personal Information",
      "class": "Steps::PersonalInfo"
    },
    "review": {
      "label": "Review",
      "class": "Steps::Review"
    }
  },
  "counts": {
    "steps": 2,
    "simple_transitions": 1,
    "conditional_transitions": 0,
    "multiple_conditional_transitions": 0,
    "custom_branching_transitions": 0
  }
}
```

**Note:** This is the unified metadata format consumed by all documentation formatters.
