# Wizard Documentation

**Structure Type:** `graph`
**Generated:** 2025-12-02T15:45:00Z
**Processor:** DfE::Wizard::StepsProcessor

## Overview

| Metric | Value |
|--------|-------|
| Total Steps | 4 |
| Simple Transitions | 2 |
| Conditional Transitions | 1 |
| Multiple Conditional Transitions | 0 |
| Custom Branching Transitions | 0 |
| **Total Transitions** | **3** |

## Root Entry Point (Fixed)

**Entry Point:** `age_check`

All users start at this step. No conditional logic applies.

## Wizard Flow

```
[:age_check]
  ↓
[:adult_form]
[:minor_form]
  ↓
[:summary]
```

### Legend

- **━━** Simple edge (linear progression, no condition)
- **─┬─** Conditional edge (if/else decision point)
- **┼** Multiple conditional edge (N-way branching)
- **⊕** Custom branching edge (complex status-driven routing)

## Steps Inventory

| Step ID | Label | Class |
|---------|-------|-------|
| `age_check` | Age Check | `Steps::AgeCheck` |
| `adult_form` | Adult Form | `Steps::AdultForm` |
| `minor_form` | Minor Form | `Steps::MinorForm` |
| `summary` | Summary | `Steps::Summary` |

## Detailed Step Specifications

### Step: `age_check`

**Label:** Age Check
**Class:** `Steps::AgeCheck`
**Entry Point:** ✓ Yes
**Exit Points:** `adult_form`, `minor_form`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

### Step: `adult_form`

**Label:** Adult Form
**Class:** `Steps::AdultForm`
**Entry Point:** ✗ No
**Exit Points:** `summary`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

### Step: `minor_form`

**Label:** Minor Form
**Class:** `Steps::MinorForm`
**Entry Point:** ✗ No
**Exit Points:** `summary`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

### Step: `summary`

**Label:** Summary
**Class:** `Steps::Summary`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

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
| `adult_form` | `summary` | Always proceeds (no condition) |
| `minor_form` | `summary` | Always proceeds (no condition) |

### Conditional Transitions (If/Else)

Conditional transitions split the flow into two branches based on a predicate evaluation.

#### `age_check` → `adult_form` OR `minor_form`

| Property | Value |
|----------|-------|
| From | `age_check` |
| Condition | `Is adult (18+)?` |
| Then (if true) | `adult_form` |
| Else (if false) | `minor_form` |

**Flow Logic:**

Evaluates the predicate `Is adult (18+)?`:
- If condition is **true** → proceed to `adult_form`
- If condition is **false** → proceed to `minor_form`

## Wizard Statistics

| Metric | Count |
|--------|-------|
| Total Steps | 4 |
| Simple Transitions | 2 |
| Conditional Transitions | 1 |
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
  "structure_type": "graph",
  "root_step": "age_check",
  "steps": {
    "age_check": {
      "label": "Age Check",
      "class": "Steps::AgeCheck"
    },
    "adult_form": {
      "label": "Adult Form",
      "class": "Steps::AdultForm"
    },
    "minor_form": {
      "label": "Minor Form",
      "class": "Steps::MinorForm"
    },
    "summary": {
      "label": "Summary",
      "class": "Steps::Summary"
    }
  },
  "counts": {
    "steps": 4,
    "simple_transitions": 2,
    "conditional_transitions": 1,
    "multiple_conditional_transitions": 0,
    "custom_branching_transitions": 0
  }
}
```

**Note:** This is the unified metadata format consumed by all documentation formatters.
