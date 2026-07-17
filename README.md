# Bulk Quote Upload using Salesforce CPQ

Upload a single Excel file containing multiple Quotes (each with multiple Quote Line Items), validate it, and asynchronously create the corresponding Accounts, Opportunities, Quotes, and Quote Lines in Salesforce CPQ — skipping and logging any invalid rows instead of failing the whole batch.

Built on **Salesforce CPQ (Revenue Cloud), package version 262.0**, using Apex, Lightning Web Components, and Salesforce CPQ's `SBQQ.ServiceRouter` API.

---

## Table of Contents

* [Features](#features)
* [Architecture](#architecture)
* [Excel Template Format](#excel-template-format)
* [Project Structure](#project-structure)
* [Prerequisites](#prerequisites)
* [Deployment](#deployment)
* [Usage](#usage)
* [Testing](#testing)
* [Known Platform Constraints](#known-platform-constraints)
* [Documentation](#documentation)
* [Author](#author)

---

# Features

* **Excel upload and parsing** via a custom Lightning Web Component (client-side parsing with SheetJS)
* **Two-step validation** — preview validation errors before anything is written to the database, then confirm to proceed
* **Automatic grouping** of Excel rows into Quotes by Quote Number, each with multiple Quote Lines
* **Find-or-create logic** for Accounts and Opportunities, deduplicated against existing org data and within the same upload batch
* **Real Salesforce CPQ pricing** — Quote Lines are created through CPQ's `SBQQ.ServiceRouter` API instead of direct DML, allowing CPQ pricing rules, discounts, and product rules to execute normally
* **Skip-invalid, continue-processing** — invalid rows and failed Quotes are logged without stopping the complete upload
* **Fully asynchronous processing** using chained Queueable jobs
* **Bulkified and governor-limit compliant** — tested with 110 Quotes and 218 Quote Lines in a single upload
* **Live processing summary** — displays Total, Successful, Failed Quotes and Quote Line progress
* **Downloadable CSV error report**
* **Original Excel file storage** against the upload process record
* **Processing History screen** to view previous uploads
* **Resilient after page refresh** — users can continue monitoring running processes

---

# Architecture

```
LWC (quoteBulkUpload)
   |
   | previewValidation()
   | (No database changes)
   v
QuoteBulkUploadController.previewValidation()
   |
   -> QuoteValidationService.validate()


User Confirmation
   |
   v

QuoteBulkUploadController.submitForProcessing()
   |
   -> QuoteValidationService.validate()
   -> QuoteGroupingService.groupByQuoteNumber()
   -> UploadProcessService.createProcess()
   -> UploadErrorService.logRowErrors()
   -> QuoteUploadQueueable


QuoteUploadQueueable
(Phase 1: Create Header Records)

   -> AccountService.getOrCreateAccounts()
   -> OpportunityService.createOpportunities()
   -> Create SBQQ__Quote__c records
   -> Start Quote Line Processing


QuoteLineProcessingQueueable
(Phase 2: CPQ Processing)

   -> CPQProductAdderService
        |
        -> SBQQ.ServiceRouter
            - QuoteReader
            - ProductLoader
            - QuoteProductAdder
            - QuoteCalculator
            - QuoteSaver


QuoteLineCorrectionQueueable

   -> Correct Quantity / Price values
   -> Continue next Quote processing
```

Complete design details are available in the Technical Design Document:

[📄 Technical Design Document](./docs/Technical_Design_Document.docx)

---

# Excel Template Format

One row represents one Quote Line. Rows having the same **Quote Number** are grouped into one Quote.

| Column           | Maps To             | Notes                            |
| ---------------- | ------------------- | -------------------------------- |
| Quote Number     | Quote grouping key  | Required                         |
| Customer Name    | Account.Name        | Matched or created               |
| Opportunity Name | Opportunity.Name    | Matched or created               |
| Quote Name       | External Quote Name |                                  |
| Product Name     | Product2.Name       | Product must exist and be active |
| Quantity         | Quote Line Quantity | Must be greater than 0           |
| Sales Price      | Quote Line Price    | Applied based on CPQ rules       |
| Quote Start Date | Quote Start Date    |                                  |
| Quote End Date   | Quote End Date      |                                  |
| Notes            | Quote Notes         |                                  |

Sample upload template:

[📊 QuoteUploadTemplate.xlsx](./docs/QuoteUploadTemplate.xlsx)

---

# Project Structure

```
force-app/main/default/

├── classes/
│
│   ├── QuoteBulkUploadController.cls
│   ├── QuoteValidationService.cls
│   ├── QuoteGroupingService.cls
│   ├── AccountService.cls
│   ├── OpportunityService.cls
│   ├── QuoteUploadQueueable.cls
│   ├── QuoteLineProcessingQueueable.cls
│   ├── QuoteLineCorrectionQueueable.cls
│   ├── CPQProductAdderService.cls
│   ├── CPQQuoteCalculatorCallback.cls
│   ├── UploadProcessService.cls
│   ├── UploadErrorService.cls
│   └── Test Classes
│
├── lwc/
│
│   ├── quoteBulkUpload/
│   └── uploadProcessingHistory/
│
└── objects/

    ├── Upload_Process__c
    └── Upload_Error__c
```

---

# Prerequisites

Before deployment:

* Salesforce Org with **Salesforce CPQ installed**
* CPQ package namespace: `SBQQ`
* Salesforce CPQ Permission Set License assigned
* SBQQ User permission set assigned
* Salesforce CLI installed

CPQ configuration requirements:

* CPQ Package Settings should be initialized
* If "Use Integration User for Calculations" is enabled:

  * Generate Integration User Permissions

---

# Deployment

### 1. Clone Repository

```bash
git clone https://github.com/<your-username>/<your-repo>.git

cd <your-repo>
```

### 2. Authorize Salesforce Org

```bash
sf org login web --alias myOrg
```

### 3. Deploy Source

```bash
sf project deploy start --target-org myOrg
```

### 4. Configure Lightning Components

Add these components using Lightning App Builder:

* `quoteBulkUpload`
* `uploadProcessingHistory`

Available locations:

* Lightning App Page
* Home Page
* Custom Tab

---

# Usage

1. Open the Bulk Quote Upload page.
2. Select an Excel file following the provided template.
3. Click **Validate**.
4. Review validation errors.
5. Click **Proceed with Processing**.
6. Background Queueable jobs process Accounts, Opportunities, Quotes, and Quote Lines.
7. Monitor progress from the processing screen.
8. Download error reports if required.

---

# Testing

Run Apex tests:

```bash
sf apex run test --target-org myOrg --code-coverage --result-format human
```

Expected coverage:

```
>90%
```

---

# Known Platform Constraints

Important Salesforce CPQ behaviors considered during implementation:

* `SBQQ.QuoteAPI.QuoteCalculator` requires quote and callback context.
* `SBQQ.QuoteProductAdder` requires bulk product processing.
* CPQ triggers require controlled updates when correcting Quote Lines.
* Quote calculation is executed in separate transactions because CPQ calculation cannot reliably happen immediately after Quote creation.
* Queueable processing is used instead of Batch Apex because CPQ internally depends on Queueable execution context.

---

# Documentation

Additional project documents:

### Technical Design Document

Contains:

* Complete architecture explanation
* Requirements traceability
* Salesforce CPQ implementation details
* Platform limitations and solutions

[📄 Technical_Design_Document.docx](./docs/Technical_Design_Document.docx)

### Sample Excel Template

Upload format example:

[📊 QuoteUploadTemplate.xlsx](./docs/QuoteUploadTemplate.xlsx)

### Demo Video

[🎥 Demo Video Link](#)

---

# Author

**Shashank**
