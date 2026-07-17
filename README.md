# Bulk Quote Upload using Salesforce CPQ

Upload a single Excel file containing multiple Quotes (each with multiple Quote Line Items), validate it, and asynchronously create the corresponding Accounts, Opportunities, Quotes, and Quote Lines in Salesforce CPQ — skipping and logging any invalid rows instead of failing the whole batch.

Built on **Salesforce CPQ (Revenue Cloud), package version 262.0**, using Apex, Lightning Web Components, and Salesforce CPQ's `SBQQ.ServiceRouter` API.

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Excel Template Format](#excel-template-format)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Deployment](#deployment)
- [Usage](#usage)
- [Testing](#testing)
- [Known Platform Constraints](#known-platform-constraints)
- [Documentation](#documentation)
- [Author](#author)

---

## Features

- **Excel upload and parsing** via a custom Lightning Web Component (client-side parsing with SheetJS)
- **Two-step validation** — preview validation errors before anything is written to the database, then confirm to proceed
- **Automatic grouping** of Excel rows into Quotes by Quote Number, each with multiple Quote Lines
- **Find-or-create logic** for Accounts and Opportunities, deduplicated both against existing org data and within the same upload batch
- **Real Salesforce CPQ pricing** — Quote Lines are added through CPQ's own `ServiceRouter` API (Read → ProductLoader → ProductAdder → Calculator → Saver), not raw `insert`, so CPQ's pricing engine, discounts, and product rules apply exactly as they would from the CPQ Line Editor
- **Skip-invalid, continue-processing** — one bad row or one failed Quote never blocks the rest of the batch
- **Fully asynchronous** — two-phase Queueable chain (header creation, then per-Quote CPQ processing) so the UI is never blocked
- **Bulkified and governor-limit compliant** — verified at 110 Quotes / 218 Quote Lines in a single upload
- **Live processing summary** — Total / Successful / Failed Quotes and Total Quote Lines, updating in real time as the batch processes
- **Downloadable error report (CSV)** — per-row and per-Quote failure details
- **Original Excel file stored** against the processing record
- **Processing History screen** — browse and re-open every past upload run
- **Resilient to page refresh** — resumes watching an in-progress run after a reload or browser restart

---

## Architecture

```
LWC (quoteBulkUpload)
   |  previewValidation()  -- read-only, no DML
   v
QuoteBulkUploadController.previewValidation()
   -> QuoteValidationService.validate()

LWC -- user confirms --
   |  submitForProcessing()
   v
QuoteBulkUploadController.submitForProcessing()
   -> QuoteValidationService.validate()          (re-validate)
   -> QuoteGroupingService.groupByQuoteNumber()
   -> UploadProcessService.createProcess()       (Upload_Process__c, Status = Pending)
   -> UploadErrorService.logRowErrors()          (row-level validation failures)
   -> enqueueJob(QuoteUploadQueueable)            [Phase 1]

QuoteUploadQueueable.execute()                   [Phase 1: header records]
   -> AccountService.getOrCreateAccounts()
   -> OpportunityService.createOpportunities()
   -> bulk Database.insert(SBQQ__Quote__c[])
   -> enqueueJob(QuoteLineProcessingQueueable)    [Phase 2, one hop per Quote]

QuoteLineProcessingQueueable.execute()            [Phase 2a: calculate + save lines]
   -> CPQProductAdderService.calculateAndSaveLines()
        -> SBQQ.ServiceRouter (QuoteReader / ProductLoader / QuoteProductAdder / QuoteCalculator)
        -> CPQQuoteCalculatorCallback.callback() -> QuoteSaver
   -> enqueueJob(QuoteLineCorrectionQueueable)    [next hop]

QuoteLineCorrectionQueueable.execute()            [Phase 2b: qty/price correction]
   -> CPQProductAdderService.correctQuantitiesAndPrices()
   -> enqueueJob(QuoteLineProcessingQueueable)    [next Quote, or complete]

(fallback only, Developer/Trial orgs — see Known Platform Constraints)
QuoteLineChainResetScheduler
   -> re-enqueues whichever Queueable was about to run, from a fresh async context
```

The full design rationale — including several Salesforce CPQ platform behaviors discovered during implementation — is documented in the [Technical Design Document](#documentation).

---

## Excel Template Format

One row per Quote Line; rows sharing the same **Quote Number** are grouped into a single Quote with multiple Quote Lines.

| Column | Maps To | Notes |
|---|---|---|
| Quote Number | Quote grouping key | Required |
| Customer Name | Account.Name | Matched or created |
| Opportunity Name | Opportunity.Name | Matched (per Account) or created |
| Quote Name | External_Quote_Name__c | |
| Product Name | Product2.Name | Must exist, be active, and have a Standard Pricebook Entry |
| Quantity | Quote Line quantity | Must be > 0 |
| Sales Price | Quote Line net price | Applied only if the product allows price editing |
| Quote Start Date | Quote start date | |
| Quote End Date | Quote end date | |
| Notes | Quote notes | |

A sample template is included at [`/data/QuoteUploadTemplate.xlsx`](./data/QuoteUploadTemplate.xlsx).

---

## Project Structure

```
force-app/main/default/
├── classes/
│   ├── QuoteBulkUploadController.cls        # LWC entry point (validate, submit, poll, history, file storage)
│   ├── QuoteValidationService.cls           # Row-level validation
│   ├── QuoteGroupingService.cls             # Groups rows into per-Quote bundles
│   ├── AccountService.cls                   # Find-or-create Accounts
│   ├── OpportunityService.cls               # Find-or-create Opportunities
│   ├── QuoteUploadQueueable.cls             # Phase 1: header record creation
│   ├── QuoteLineProcessingQueueable.cls     # Phase 2a: calculate + save Quote Lines
│   ├── QuoteLineCorrectionQueueable.cls     # Phase 2b: quantity/price correction
│   ├── QuoteLineChainResetScheduler.cls     # Chain-depth fallback (Dev/Trial orgs)
│   ├── CPQProductAdderService.cls           # SBQQ.ServiceRouter integration
│   ├── CPQQuoteCalculatorCallback.cls       # SBQQ.CalculateCallback implementation
│   ├── UploadProcessService.cls             # Upload_Process__c status/progress management
│   ├── UploadErrorService.cls               # Upload_Error__c logging
│   ├── ExcelRowWrapper.cls / QuoteGroupWrapper.cls / QuoteUploadResponse.cls / RowError.cls
│   └── *Test.cls                            # Unit tests
├── lwc/
│   ├── quoteBulkUpload/                     # Main upload, validation, and results screen
│   └── uploadProcessingHistory/             # Processing history screen
└── objects/
    ├── Upload_Process__c/                   # Tracks one upload run
    └── Upload_Error__c/                     # Row/Quote-level failure detail (Master-Detail to Upload_Process__c)
```

---

## Prerequisites

- A Salesforce org with **Salesforce CPQ** (managed package, namespace `SBQQ`) installed
- The running user must have:
  - The **Salesforce CPQ** Permission Set License assigned
  - The **SBQQ User** permission set assigned
- CPQ **Package Settings** must have been saved at least once (Setup → Installed Packages → Salesforce CPQ → Configure → save any tab) to initialize the `SBQQ__Setup__c` configuration record
- If **"Use Integration User for Calculations"** is enabled under CPQ Package Settings → Pricing and Calculation, click **Generate Integration User Permissions** once
- Salesforce CLI (`sf`) installed for deployment

---

## Deployment

1. Clone this repository:
   ```bash
   git clone https://github.com/<your-username>/<your-repo>.git
   cd <your-repo>
   ```

2. Authorize your org:
   ```bash
   sf org login web --alias myOrg
   ```

3. Create the two custom objects (`Upload_Process__c`, `Upload_Error__c`) and the two custom fields on `SBQQ__Quote__c` (`Excel_Quote_Number__c`, `External_Quote_Name__c`) if they aren't already present in your org — see the [Technical Design Document](#documentation) for the full field list.

4. Deploy the source:
   ```bash
   sf project deploy start --target-org myOrg
   ```

5. Add the `quoteBulkUpload` and `uploadProcessingHistory` components to a Lightning App Page, Home Page, or Tab via **Lightning App Builder** — they are not auto-exposed anywhere by default.

6. (Optional) Add the **Files** related list to the `Upload_Process__c` page layout to make stored Excel files easier to browse — they're also reachable via the standard Notes & Attachments related list without this step.

---

## Usage

1. Open the Quote Bulk Upload screen and select an `.xlsx` file matching the template format.
2. Click **Validate** — review any row-level errors before proceeding. No data is written yet at this point.
3. Click **Proceed with Processing** to confirm. Processing runs asynchronously in the background.
4. Watch the live progress panel, or navigate away and come back later — the run resumes tracking automatically.
5. Download the error report if any rows or Quotes failed.
6. Use the **Processing History** screen to review or re-check any past upload.

---

## Testing

Run the full test suite:

```bash
sf apex run test --target-org myOrg --code-coverage --result-format human
```

Test coverage target: **>90%** org-wide, per the project requirements.

---

## Known Platform Constraints

A few Salesforce CPQ / Apex platform behaviors materially shaped this design — full detail is in the TDD, summarized here:

- **`SBQQ.QuoteAPI.QuoteCalculator` requires a `{quote, callbackClass}` context object**, not a raw quote model, and the named callback class must implement `SBQQ.CalculateCallback`.
- **`SBQQ.QuoteAPI.QuoteProductAdder` must receive all products to add in a single call** — calling it once per product and threading the result through a loop silently loses earlier lines.
- **CPQ's own `SBQQ__QuoteLine__c` trigger reacts to manual Quote Line updates** made outside the CPQ Line Editor; `SBQQ.TriggerControl.disable()/enable()` is used around the quantity/price correction step to prevent this.
- **A Quote cannot reliably be calculated in the same transaction it was inserted in** — this is why record creation (Phase 1) and CPQ processing (Phase 2) run in separate, chained Queueable transactions.
- **Queueable chain depth is capped at 5 in Developer Edition and Trial orgs only** (no cap in Production/Sandbox) — `QuoteLineChainResetScheduler` exists specifically as a fallback for this and is expected to be inert outside Developer/Trial orgs.
- **Batch Apex is not used** — CPQ's internal trigger logic calls `AsyncInfo.hasMaxStackDepth()`, which is only valid inside a Queueable or Finalizer execution context.

---

## Documentation

- **Technical Design Document** — full architecture, requirements traceability, and platform-constraint writeups: [`/docs/Technical_Design_Document.docx`](./docs/Technical_Design_Document.docx)
- **Demo Video** — [link here]
- **Sample Excel Template** — [`/data/QuoteUploadTemplate.xlsx`](./data/QuoteUploadTemplate.xlsx)

---

## Author

**Shashank**
