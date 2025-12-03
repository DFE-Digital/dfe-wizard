# Wizard Documentation

**Structure Type:** `graph`
**Generated:** 2025-12-02T15:45:00Z
**Processor:** DfE::Wizard::StepsProcessor

## Overview

| Metric | Value |
|--------|-------|
| Total Steps | 3 |
| Simple Transitions | 2 |
| Conditional Transitions | 0 |
| Multiple Conditional Transitions | 0 |
| Custom Branching Transitions | 0 |
| **Total Transitions** | **2** |

## Root Entry Points (Dynamic)

This wizard uses conditional root logic. Users may enter at different steps based on runtime state evaluation.

### Possible Entry Points

- `login`
- `register`

**Determination:** Evaluated at initialization based on wizard state. See "Conditional Root Logic" section for details on which conditions route to which entry points.

## Wizard Flow

```
[:login]
  ↓
[:register]
  ↓
[:dashboard]
```

### Legend

- **━━** Simple edge (linear progression, no condition)
- **─┬─** Conditional edge (if/else decision point)
- **┼** Multiple conditional edge (N-way branching)
- **⊕** Custom branching edge (complex status-driven routing)

## Steps Inventory

| Step ID | Label | Class |
|---------|-------|-------|
| `login` | Login | `Steps::Login` |
| `register` | Register | `Steps::Register` |
| `dashboard` | Dashboard | `Steps::Dashboard` |

## Detailed Step Specifications

### Step: `login`

**Label:** Login
**Class:** `Steps::Login`
**Entry Point:** ✓ Yes
**Exit Points:** `dashboard`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

### Step: `register`

**Label:** Register
**Class:** `Steps::Register`
**Entry Point:** ✓ Yes
**Exit Points:** `dashboard`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

### Step: `dashboard`

**Label:** Dashboard
**Class:** `Steps::Dashboard`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

## Transitions Reference

This wizard contains **2 transitions** across 4 types:

- **2 simple transitions** – Linear progression (unconditional)
- **0 conditional transitions** – If/else branching logic
- **0 multiple conditional transitions** – N-way branching
- **0 custom branching transitions** – Complex status-driven routing

### Simple Transitions

Simple transitions allow linear, unconditional progression from one step to the next.

| From | To | Behavior |
|------|-----|----------|
| `login` | `dashboard` | Always proceeds (no condition) |
| `register` | `dashboard` | Always proceeds (no condition) |

## Wizard Statistics

| Metric | Count |
|--------|-------|
| Total Steps | 3 |
| Simple Transitions | 2 |
| Conditional Transitions | 0 |
| Multiple Conditional Transitions | 0 |
| Custom Branching Transitions | 0 |
| **Total Transitions** | **2** |

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
  "root_step": ["login", "register"],
  "steps": {
    "login": {
      "label": "Login",
      "class": "Steps::Login"
    },
    "register": {
      "label": "Register",
      "class": "Steps::Register"
    },
    "dashboard": {
      "label": "Dashboard",
      "class": "Steps::Dashboard"
    }
  },
  "counts": {
    "steps": 3,
    "simple_transitions": 2,
    "conditional_transitions": 0,
    "multiple_conditional_transitions": 0,
    "custom_branching_transitions": 0
  }
}
```

**Note:** This is the unified metadata format consumed by all documentation formatters.
