# Wizard Documentation - Graph Without Operations

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

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `org_type` | `Enum` | ✓ | Type of organization |
| `company_number` | `String` | ✗ | Company registration |

#### Validations

- **org_type** (`presence`): cannot be blank

### Step: `waste_category`

**Label:** Waste Category
**Class:** `Steps::WasteCategory`
**Entry Point:** ✗ No
**Exit Points:** `activity_type`, `office_address`

#### Description

Placeholder for step description.

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `category` | `Enum` | ✓ | Waste classification |

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

#### Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `address_line_1` | `String` | ✓ | First line |
| `address_line_2` | `String` | ✗ | Second line |
| `city` | `String` | ✓ | City or town |
| `postcode` | `String` | ✓ | UK postcode |

#### Validations

- **address_line_1** (`presence`): cannot be blank
- **postcode** (`format`): must be valid

### Step: `review`

**Label:** Review Application
**Class:** `Steps::Review`
**Entry Point:** ✗ No
**Exit Points:** `review`, `issue_certificate`, `rejection_notice`, `pending_info`

#### Description

Placeholder for step description.

### Step: `issue_certificate`

**Label:** Issue Certificate
**Class:** `Steps::IssueCertificate`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description.

### Step: `rejection_notice`

**Label:** Rejection Notice
**Class:** `Steps::RejectionNotice`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description.

### Step: `pending_info`

**Label:** Pending Information
**Class:** `Steps::PendingInfo`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description.

## Wizard Statistics

| Metric | Count |
|--------|-------|
| Total Steps | 8 |
| Simple Transitions | 2 |
| Conditional Transitions | 1 |
| Multiple Conditional Transitions | 1 |
| Custom Branching Transitions | 1 |
| **Total Transitions** | **5** |
