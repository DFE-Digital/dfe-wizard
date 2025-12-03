# Wizard Documentation - Graph Without Attributes

**Structure Type:** `graph`
**Generated:** 2025-12-02T15:45:00Z
**Processor:** DfE::Wizard::StepsProcessor

## Overview

| Metric | Value |
|--------|-------|
| Total Steps | 8 |
| Simple Transitions | 2 |
| Conditional Transitions | 1 |
| Multiple Conditional Transitions | 1 |
| Custom Branching Transitions | 1 |
| **Total Transitions** | **5** |

## Root Entry Point (Fixed)

**Entry Point:** `organization_type`

## Steps Inventory

| Step ID | Label | Class |
|---------|-------|-------|
| `organization_type` | Organization Type | `Steps::OrganizationType` |
| `waste_category` | Waste Category | `Steps::WasteCategory` |
| `activity_type` | Activity Type | `Steps::ActivityType` |
| `office_address` | Office Address | `Steps::OfficeAddress` |
| `review` | Review | `Steps::Review` |
| `issue_certificate` | Issue Certificate | `Steps::IssueCertificate` |
| `rejection_notice` | Rejection Notice | `Steps::RejectionNotice` |
| `pending_info` | Pending Info | `Steps::PendingInfo` |

## Detailed Step Specifications

### Step: `organization_type`

**Label:** Organization Type
**Class:** `Steps::OrganizationType`
**Entry Point:** ✓ Yes
**Exit Points:** `waste_category`

#### Description

Placeholder for step description.

#### Validations

- **org_type** (`presence`): cannot be blank

#### Operations

| Operation | Description |
|-----------|-------------|
| `format_company_number` | Format company number |

### Step: `waste_category`

**Label:** Waste Category
**Class:** `Steps::WasteCategory`
**Entry Point:** ✗ No
**Exit Points:** `activity_type`, `office_address`

#### Description

Placeholder for step description.

#### Validations

- **category** (`inclusion`): must be valid

### Step: `activity_type`

**Label:** Activity Type
**Class:** `Steps::ActivityType`
**Entry Point:** ✗ No
**Exit Points:** `office_address`, `review`

#### Description

Placeholder for step description.

### Step: `office_address`

**Label:** Office Address
**Class:** `Steps::OfficeAddress`
**Entry Point:** ✗ No
**Exit Points:** `review`

#### Description

Placeholder for step description.

#### Validations

- **address_line_1** (`presence`): cannot be blank
- **postcode** (`format`): must be valid

#### Operations

| Operation | Description |
|-----------|-------------|
| `geocode_address` | Lookup coordinates |

### Step: `review`

**Label:** Review Application
**Class:** `Steps::Review`
**Entry Point:** ✗ No
**Exit Points:** `review`, `issue_certificate`, `rejection_notice`, `pending_info`

#### Description

Placeholder for step description.

#### Operations

| Operation | Description |
|-----------|-------------|
| `validate_completeness` | Check fields |

### Step: `issue_certificate`

**Label:** Issue Certificate
**Class:** `Steps::IssueCertificate`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description.

#### Operations

| Operation | Description |
|-----------|-------------|
| `generate_certificate` | Generate PDF |
| `send_certificate_email` | Email certificate |

### Step: `rejection_notice`

**Label:** Rejection Notice
**Class:** `Steps::RejectionNotice`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description.

#### Operations

| Operation | Description |
|-----------|-------------|
| `send_rejection_email` | Notify applicant |

### Step: `pending_info`

**Label:** Pending Information
**Class:** `Steps::PendingInfo`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description.

## Transitions Reference

- **2 simple transitions** – Linear progression
- **1 conditional transitions** – If/else branching
- **1 multiple conditional transitions** – N-way branching
- **1 custom branching transitions** – Complex routing

## Wizard Statistics

| Metric | Count |
|--------|-------|
| Total Steps | 8 |
| Simple Transitions | 2 |
| Conditional Transitions | 1 |
| Multiple Conditional Transitions | 1 |
| Custom Branching Transitions | 1 |
| **Total Transitions** | **5** |
